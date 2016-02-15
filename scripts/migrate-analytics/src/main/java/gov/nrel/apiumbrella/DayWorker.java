package gov.nrel.apiumbrella;

import java.io.IOException;
import java.math.BigInteger;
import java.net.MalformedURLException;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.text.NumberFormat;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Locale;
import java.util.Map;

import org.apache.avro.Schema;
import org.apache.avro.generic.GenericData;
import org.apache.avro.generic.GenericRecord;
import org.apache.parquet.avro.AvroParquetWriter;
import org.apache.parquet.hadoop.ParquetWriter;
import org.apache.parquet.hadoop.metadata.CompressionCodecName;
import org.joda.time.DateTime;
import org.joda.time.DateTimeZone;
import org.joda.time.Period;
import org.joda.time.format.DateTimeFormatter;
import org.joda.time.format.ISODateTimeFormat;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;

import io.searchbox.client.JestClient;
import io.searchbox.client.JestClientFactory;
import io.searchbox.client.JestResult;
import io.searchbox.client.config.HttpClientConfig;
import io.searchbox.core.Search;
import io.searchbox.core.SearchScroll;
import io.searchbox.params.Parameters;

public class DayWorker implements Runnable {
  private DateTime date;
  private String startDateString;
  private String endDateString;
  private Schema schema;
  private HashSet<String> schemaIntFields;
  private HashSet<String> schemaDoubleFields;
  private HashSet<String> schemaBooleanFields;
  private App app;
  private int totalProcessedHits = 0;
  private int totalHits;
  ParquetWriter<GenericRecord> parquetWriter;
  DateTimeFormatter dateTimeParser = ISODateTimeFormat.dateTimeParser();
  DateTimeFormatter dateFormatter = ISODateTimeFormat.date();

  public DayWorker(App app, DateTime date) {
    this.app = app;
    this.date = date;
    this.schema = app.getSchema();
    this.schemaIntFields = app.getSchemaIntFields();
    this.schemaDoubleFields = app.getSchemaDoubleFields();
    this.schemaBooleanFields = app.getSchemaBooleanFields();

    this.startDateString = this.dateFormatter.print(this.date);
    DateTime tomorrow = this.date.plus(Period.days(1));
    this.endDateString = this.dateFormatter.print(tomorrow);
  }

  public void run() {
    try {
      JestClientFactory factory = new JestClientFactory();
      factory.setHttpClientConfig(new HttpClientConfig.Builder(App.ELASTICSEARCH_URL)
        .multiThreaded(true)
        .connTimeout(10000)
        .readTimeout(30000)
        .build());
      JestClient client = factory.getObject();

      // Perform a scroll query to fetch the specified day's data from
      // elasticsearch.
      String query = "{" + //
        "  \"sort\":\"request_at\"," + //
        "  \"query\":{" + //
        "    \"filtered\":{" + //
        "      \"filter\":{" + //
        "        \"range\":{" + //
        "          \"request_at\":{" + //
        "            \"gte\":\"" + this.startDateString + "\"," + //
        "            \"lt\":\"" + this.endDateString + "\"" + //
        "          }" + //
        "        }" + //
        "      }" + //
        "    }" + //
        "  }" + //
        "}";
      String indexName = "api-umbrella-logs-" + ISODateTimeFormat.yearMonth().print(this.date);
      Search search = new Search.Builder(query)
        .addIndex(indexName)
        .setParameter(Parameters.SIZE, App.PAGE_SIZE)
        .setParameter(Parameters.SCROLL, "1m")
        .build();

      JestResult result = client.execute(search);
      if(!result.isSucceeded()) {
        System.out.println(result.getErrorMessage());
        System.exit(1);
      }

      String scrollId = result.getJsonObject().get("_scroll_id").getAsString();
      this.totalHits = result.getJsonObject().getAsJsonObject("hits").get("total").getAsInt();

      while(true) {
        // Keep looping until the scroll result returns no results.
        if(!processResult(result)) {
          break;
        }

        SearchScroll scroll = new SearchScroll.Builder(scrollId, "1m").build();
        result = client.execute(scroll);
        if(!result.isSucceeded()) {
          System.out.println(result.getErrorMessage());
          System.exit(1);
        }

        scrollId = result.getJsonObject().get("_scroll_id").getAsString();
      }

      // Close the parquet file (but only if it exists, so we skip over days
      // with no data).
      if(this.parquetWriter != null) {
        parquetWriter.close();
      }
    } catch(Exception e) {
      e.printStackTrace();
      System.exit(1);
    }
  }

  private ParquetWriter<GenericRecord> getParquetWriter() {
    if(this.parquetWriter == null) {
      try {
        // Create a new file in /dir/YYYY/MM/YYYY-MM-DD.par
        Path path = Paths.get(App.DIR,
          this.date.toString("YYYY"),
          this.date.toString("MM"),
          this.startDateString + ".par");
        Files.createDirectories(path.getParent());

        this.parquetWriter = AvroParquetWriter
          .<GenericRecord> builder(new org.apache.hadoop.fs.Path(path.toString()))
          .withSchema(schema)
          .withCompressionCodec(CompressionCodecName.SNAPPY)
          .withDictionaryEncoding(true)
          .withValidation(false)
          .build();
      } catch(IOException e) {
        e.printStackTrace();
        System.exit(1);
      }
    }

    return this.parquetWriter;
  }

  private boolean processResult(JestResult result) throws Exception {
    JsonArray hits = result.getJsonObject().getAsJsonObject("hits").getAsJsonArray("hits");

    int pageHits = hits.size();
    if(pageHits == 0) {
      return false;
    }

    this.totalProcessedHits += pageHits;

    BigInteger globalHits = this.app.incrementGlobalHits(pageHits);
    NumberFormat numberFormatter = NumberFormat.getNumberInstance(Locale.US);
    DateTime firstRequestAt = this.parseTimestamp(
      hits.get(0).getAsJsonObject().get("_source").getAsJsonObject().get("request_at"));
    System.out.println(String.format(
      "%s | Thread %2s | Processing %s to %s | %10s / %10s | %12s | %s",
      new DateTime(),
      Thread.currentThread().getId(),
      this.startDateString,
      this.endDateString,
      numberFormatter.format(this.totalProcessedHits),
      numberFormatter.format(this.totalHits),
      numberFormatter.format(globalHits),
      firstRequestAt));

    for(int i = 0; i < pageHits; i++) {
      JsonObject hit = hits.get(i).getAsJsonObject();
      this.processHit(hit);
    }

    return true;
  }

  private void processHit(JsonObject hit) throws Exception {
    JsonObject source = hit.get("_source").getAsJsonObject();

    try {
      // For each hit, create a new Avro record to serialize it into the new
      // format for parquet storage.
      GenericRecord log = new GenericData.Record(schema);
      log.put("id", hit.get("_id"));

      // Loop over each attribute in the source data, assigning each value to
      // the
      // new data record.
      for(Map.Entry<String, JsonElement> entry : source.entrySet()) {
        String key = entry.getKey();

        // Skip this field if we've explicitly marked it as not migrating.
        if(App.SKIP_FIELDS.contains(key)) {
          continue;
        }

        JsonElement value = entry.getValue();

        // Skip setting anything if the value is null.
        if(value == null || value.isJsonNull()) {
          continue;
        }

        // Handle special processing for certain fields.
        switch(key) {
        case "request_at":
          // Split up the timestamp into several fields for better compatibility
          // with the Kylin's cube's that will be created (which doesn't support
          // timestamps yet).
          DateTime requestAt = this.parseTimestamp(value);
          log.put("request_at", requestAt.getMillis());
          log.put("request_at_year", requestAt.getYear());
          log.put("request_at_month", requestAt.getMonthOfYear());
          log.put("request_at_date", this.dateFormatter.print(requestAt));
          log.put("request_at_hour", requestAt.getHourOfDay());
          log.put("request_at_minute", requestAt.getMinuteOfHour());
          value = null;
          break;
        case "request_ip_location":
          // Flatten the location object into two separate fields.
          log.put("request_ip_lat", value.getAsJsonObject().get("lat").getAsDouble());
          log.put("request_ip_lon", value.getAsJsonObject().get("lon").getAsDouble());
          value = null;
          break;
        case "request_url":
          // Perform various cleanup and sanity checks on storing the URL as
          // separate fields (versus the duplicative separate fields plus a full
          // URL field). The full URL field sometimes differs in the data versus
          // the individual fields, so we want to make sure we're transferring
          // the
          // best data possible and not losing anything in the process.
          URL url;
          try {
            url = new URL(value.getAsString());
          } catch(MalformedURLException e) {
            try {
              // Cleanup some oddities in some invalid URLs seen (I think from
              // localhost testing).
              url = new URL(
                value.getAsString().replace(":80:80/", ":80/").replace("://[", "://").replace("]/",
                  "/"));
            } catch(MalformedURLException e2) {
              System.out.println("Thread " + Thread.currentThread().getId());
              System.out.println(hit);
              throw(e2);
            }
          }

          // Store the original request_scheme, since that seems to be more
          // accurate than sometimes incorrect http:// urls on request_url that
          // are actually https.
          String requestScheme = source.get("request_scheme").getAsString();
          if(!url.getProtocol().equals(requestScheme)) {
            System.out.println("WARNING: request_url's scheme (" + url.getProtocol()
              + ") does not match request_scheme (" + requestScheme + ")");
          }
          log.put("request_url_scheme", requestScheme);

          // Store the host extracted from the full URL, since that seems more
          // accurate than the separate request_host field (it seems to better
          // handle some odd invalid hostnames, which probably don't actually
          // matter too much).
          String requestHost = source.get("request_host").getAsString();
          if(!url.getHost().equals(requestHost)) {
            System.out.println("WARNING: request_url's host (" + url.getHost()
              + ") does not match request_host (" + requestHost + ")");
          }
          log.put("request_url_host", url.getHost());

          // As a new field, store the port used. Most of the time this will be
          // the default 80 or 443, depending on the scheme.
          int urlPort = url.getPort();
          if(log.get("request_url_scheme").equals("https") && urlPort == 80) {
            log.put("request_url_port", 443);
          } else {
            // If the port isn't set, or it's 50090, set it to the default port
            // based on the scheme. We're ignoring port 50090, since this is
            // present on some of our rather old imported logs, and was an
            // internal-only port that was used (but was never public, so this
            // isn't accurate).
            if(urlPort == -1 || urlPort == 50090) {
              if(log.get("request_url_scheme").equals("https")) {
                log.put("request_url_port", 443);
              } else {
                log.put("request_url_port", 80);
              }
            } else {
              log.put("request_url_port", urlPort);
            }
          }

          // Store the path extracted from the full URL, since it seems to be
          // more
          // accurate at dealing with odd URL encoding issues.
          String requestPath = source.get("request_path").getAsString();
          if(!url.getPath().equals(requestPath)) {
            System.out.println("WARNING: request_url's path (" + url.getPath()
              + ") does not match request_path (" + requestPath + ")");
          }
          log.put("request_url_path", url.getPath());

          // Store the query string extracted from the full URL.
          String requestQuery = url.getQuery();
          log.put("request_url_query", requestQuery);

          // If a hash fragment is present in the full URL, this is actually a
          // flag that something's fishy with the URL encoding, since our
          // server-side logs can't possible contain fragment information. So
          // we'll assume this information actually represents something
          // following
          // a URL-encoded hash fragment, and append that to the appropriate
          // place.
          String urlRef = url.getRef();
          if(urlRef != null) {
            if(log.get("request_url_query") != null) {
              log.put("request_url_query", log.get("request_url_query") + "%23" + urlRef);
            } else {
              log.put("request_url_path", log.get("request_url_path") + "%23" + urlRef);
            }
          }

          // Re-assemble the URL based on all of our newly stored individual
          // componetns.
          String reassmbledUrl = log.get("request_url_scheme") + "://"
            + log.get("request_url_host");
          if(log.get("request_url_scheme").equals("http")) {
            if((Integer) log.get("request_url_port") != 80) {
              reassmbledUrl = reassmbledUrl + ":" + log.get("request_url_port");
            }
          } else if(log.get("request_url_scheme").equals("https")) {
            if((Integer) log.get("request_url_port") != 443) {
              reassmbledUrl = reassmbledUrl + ":" + log.get("request_url_port");
            }
          } else {
            reassmbledUrl = reassmbledUrl + ":" + log.get("request_url_port");
          }
          reassmbledUrl = reassmbledUrl + log.get("request_url_path");
          if(requestQuery != null) {
            reassmbledUrl = reassmbledUrl + "?" + log.get("request_url_query");
          }

          // As a last sanity check to make sure we're not throwing away data as
          // part of this migration, compare the original full URL string to the
          // new URL composed of the various parts.
          if(!value.getAsString().equals(reassmbledUrl)) {
            // Ignore some of the default ports for comparison.
            if(!value.getAsString().replaceFirst(":(80|443|50090)/", "/").equals(reassmbledUrl)) {
              System.out.println("WARNING: request_url (" + value.getAsString()
                + ") does not match reassembled URL (" + reassmbledUrl + ")");
            }
          }

          value = null;
          break;

        // The following are some renamed fields to better normalize the new
        // storage schema.
        case "response_time":
          key = "timer_response";
          break;
        case "backend_response_time":
          key = "timer_backend_response";
          break;
        case "internal_gatekeeper_time":
          key = "timer_internal";
          break;
        case "proxy_overhead":
          key = "timer_proxy_overhead";
          break;
        case "gatekeeper_denied_code":
          key = "denied_reason";
          break;
        case "imported":
          key = "log_imported";
          break;
        }

        if(value != null) {
          // Set the value on the new record, performing type-casting as needed.
          try {
            if(this.schemaIntFields.contains(key)) {
              log.put(key, value.getAsInt());
            } else if(this.schemaDoubleFields.contains(key)) {
              log.put(key, value.getAsDouble());
            } else if(this.schemaBooleanFields.contains(key)) {
              log.put(key, value.getAsBoolean());
            } else {
              try {
                log.put(key, value.getAsString());
              } catch(IllegalStateException e) {
                // Handle some unexpected array types by comma-delimiting the
                // values.
                if(value.isJsonArray()) {
                  StringBuffer buffer = new StringBuffer();
                  Iterator<JsonElement> iter = value.getAsJsonArray().iterator();
                  while(iter.hasNext()) {
                    buffer.append(iter.next().getAsString());
                    if(iter.hasNext()) {
                      buffer.append(", ");
                    }
                  }
                  log.put(key, buffer.toString());
                } else {
                  throw(e);
                }
              }
            }
          } catch(Exception e) {
            System.out.println("Eror on field: " + key);
            System.out.println(e.getMessage());
            throw(e);
          }
        }
      }

      this.getParquetWriter().write(log);
    } catch(Exception e) {
      System.out.println("Error on hit: " + hit);
      System.out.println(e.getMessage());
      System.out.println("Error on thread: " + Thread.currentThread().getId());
      throw(e);
    }
  }

  private DateTime parseTimestamp(JsonElement value) {
    if(value.getAsJsonPrimitive().isNumber()) {
      return new DateTime(value.getAsLong(), DateTimeZone.UTC);
    } else {
      return this.dateTimeParser.parseDateTime(value.getAsString());
    }
  }
}
