package apiumbrella.hadoop_analytics;

import java.io.IOException;
import java.math.BigInteger;
import java.net.MalformedURLException;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.file.Paths;
import java.text.NumberFormat;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.apache.avro.Schema;
import org.apache.avro.generic.GenericData;
import org.apache.avro.generic.GenericRecord;
import org.apache.commons.lang.StringUtils;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.hive.ql.io.orc.CompressionKind;
import org.apache.hadoop.hive.ql.io.orc.OrcFile;
import org.apache.hadoop.hive.ql.io.orc.OrcFile.WriterOptions;
import org.apache.hadoop.hive.ql.io.orc.Writer;
import org.apache.hadoop.hive.serde2.io.DoubleWritable;
import org.apache.hadoop.hive.serde2.io.ShortWritable;
import org.apache.hadoop.hive.serde2.objectinspector.ObjectInspector;
import org.apache.hadoop.hive.serde2.objectinspector.StructField;
import org.apache.hadoop.hive.serde2.objectinspector.primitive.PrimitiveObjectInspectorFactory;
import org.apache.hadoop.io.BooleanWritable;
import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.LongWritable;
import org.apache.hadoop.io.Text;
import org.joda.time.DateTime;
import org.joda.time.DateTimeZone;
import org.joda.time.Period;
import org.joda.time.format.DateTimeFormat;
import org.joda.time.format.DateTimeFormatter;
import org.joda.time.format.ISODateTimeFormat;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonPrimitive;

import io.searchbox.client.JestClient;
import io.searchbox.client.JestClientFactory;
import io.searchbox.client.JestResult;
import io.searchbox.client.config.HttpClientConfig;
import io.searchbox.core.Search;
import io.searchbox.core.SearchScroll;
import io.searchbox.params.Parameters;

public class DayWorker implements Runnable {
  final Logger logger = LoggerFactory.getLogger(DayWorker.class);

  private DateTime dayStartTime;
  private DateTime dayEndTime;
  private static LogSchema schema;
  private App app;
  private int totalProcessedHits = 0;
  private int totalHits;
  private static WriterOptions orcWriterOptions;
  private Writer orcWriter;
  DateTimeFormatter dateTimeParser = ISODateTimeFormat.dateTimeParser();
  DateTimeFormatter dateTimeFormatter =
      DateTimeFormat.forPattern("yyyy-MM-dd HH:mm:ss").withZone(App.TIMEZONE);
  DateTimeFormatter dateFormatter = ISODateTimeFormat.date().withZone(App.TIMEZONE);

  public DayWorker(App app, DateTime date) {
    this.app = app;
    dayStartTime = date;
    dayEndTime = this.dayStartTime.plus(Period.days(1));
    schema = new LogSchema();
  }

  public void run() {
    try {
      JestClientFactory factory = new JestClientFactory();
      factory.setHttpClientConfig(new HttpClientConfig.Builder(App.ELASTICSEARCH_URL)
          .multiThreaded(true).connTimeout(60000).readTimeout(120000).build());
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
          "            \"gte\":" + this.dayStartTime.getMillis() + "," + //
          "            \"lt\":" + this.dayEndTime.getMillis() + //
          "          }" + //
          "        }" + //
          "      }" + //
          "    }" + //
          "  }" + //
          "}";
      // Query the indexes that cover this day (this may involve multiple indexes on month
      // boundaries, if we're converting into a timezone, since the indexes are UTC-based).
      String startTimeIndex = "api-umbrella-logs-"
          + ISODateTimeFormat.yearMonth().withZone(DateTimeZone.UTC).print(dayStartTime);
      String endTimeIndex = "api-umbrella-logs-"
          + ISODateTimeFormat.yearMonth().withZone(DateTimeZone.UTC).print(dayEndTime);
      Search search = new Search.Builder(query).ignoreUnavailable(true).addIndex(startTimeIndex)
          .addIndex(endTimeIndex).setParameter(Parameters.SIZE, App.PAGE_SIZE)
          .setParameter(Parameters.SCROLL, "3m").build();

      JestResult result = client.execute(search);
      if (!result.isSucceeded()) {
        logger.error(result.getErrorMessage());
        System.exit(1);
      }

      String scrollId = result.getJsonObject().get("_scroll_id").getAsString();
      this.totalHits = result.getJsonObject().getAsJsonObject("hits").get("total").getAsInt();

      while (true) {
        // Keep looping until the scroll result returns no results.
        if (!processResult(result)) {
          break;
        }

        SearchScroll scroll = new SearchScroll.Builder(scrollId, "3m").build();
        result = client.execute(scroll);
        if (!result.isSucceeded()) {
          logger.error(result.getErrorMessage());
          System.exit(1);
        }

        scrollId = result.getJsonObject().get("_scroll_id").getAsString();
      }

      // Close the data file (but only if it exists, so we skip over days
      // with no data).
      if (this.orcWriter != null) {
        this.orcWriter.close();
        this.orcWriter = null;
      }
    } catch (Exception e) {
      logger.error("Unexpected error", e);
      System.exit(1);
    }
  }

  private static WriterOptions getOrcWriterOptions() throws IOException {
    if (orcWriterOptions == null) {
      ArrayList<StructField> orcFields = new ArrayList<StructField>();
      for (int i = 0; i < schema.getNonPartitionFieldsList().size(); i++) {
        String field = schema.getNonPartitionFieldsList().get(i);
        Schema.Type type = schema.getFieldType(field);

        ObjectInspector inspector;
        if (type == Schema.Type.INT) {
          if (schema.isFieldTypeShort(field)) {
            inspector = PrimitiveObjectInspectorFactory.writableShortObjectInspector;
          } else {
            inspector = PrimitiveObjectInspectorFactory.writableIntObjectInspector;
          }
        } else if (type == Schema.Type.LONG) {
          inspector = PrimitiveObjectInspectorFactory.writableLongObjectInspector;
        } else if (type == Schema.Type.DOUBLE) {
          inspector = PrimitiveObjectInspectorFactory.writableDoubleObjectInspector;
        } else if (type == Schema.Type.BOOLEAN) {
          inspector = PrimitiveObjectInspectorFactory.writableBooleanObjectInspector;
        } else if (type == Schema.Type.STRING) {
          inspector = PrimitiveObjectInspectorFactory.writableStringObjectInspector;
        } else {
          throw new IOException("Unknown type: " + type.toString());
        }

        orcFields.add(new OrcField(field, inspector, i));
      }

      Configuration conf = new Configuration();
      // Fix for hadoop jar ordering: http://stackoverflow.com/a/21118824
      conf.set("fs.hdfs.impl", org.apache.hadoop.hdfs.DistributedFileSystem.class.getName());
      conf.set("fs.file.impl", org.apache.hadoop.fs.LocalFileSystem.class.getName());

      orcWriterOptions = OrcFile.writerOptions(conf);
      orcWriterOptions.compress(CompressionKind.ZLIB);
      orcWriterOptions.inspector(new OrcRowInspector(orcFields));
    }

    return orcWriterOptions;
  }

  private Writer getOrcWriter() throws IOException {
    if (this.orcWriter == null) {
      String date = dateFormatter.print(dayStartTime);
      // Create a new file in /dir/YYYY/MM/WW/YYYY-MM-DD.par
      Path path = new Path(App.HDFS_URI + Paths.get(App.DIR,
          "timestamp_tz_year=" + dateFormatter.print(dayStartTime.withDayOfYear(1)),
          "timestamp_tz_month=" + dateFormatter.print(dayStartTime.withDayOfMonth(1)),
          "timestamp_tz_week=" + dateFormatter.print(dayStartTime.withDayOfWeek(1)),
          "timestamp_tz_date=" + date, date + ".orc"));
      this.orcWriter = OrcFile.createWriter(path, getOrcWriterOptions());
    }

    return this.orcWriter;
  }

  private boolean processResult(JestResult result) throws Exception {
    JsonArray hits = result.getJsonObject().getAsJsonObject("hits").getAsJsonArray("hits");

    int pageHits = hits.size();
    if (pageHits == 0) {
      return false;
    }

    this.totalProcessedHits += pageHits;

    BigInteger globalHits = this.app.incrementGlobalHits(pageHits);
    NumberFormat numberFormatter = NumberFormat.getNumberInstance(Locale.US);
    DateTime firstRequestAt = this.parseTimestamp(
        hits.get(0).getAsJsonObject().get("_source").getAsJsonObject().get("request_at"));
    logger.info(String.format("Processing %s to %s | %10s / %10s | %12s | %s", this.dayStartTime,
        this.dayEndTime, numberFormatter.format(this.totalProcessedHits),
        numberFormatter.format(this.totalHits), numberFormatter.format(globalHits),
        firstRequestAt));

    for (int i = 0; i < pageHits; i++) {
      JsonObject hit = hits.get(i).getAsJsonObject();
      this.processHit(hit);
    }

    return true;
  }

  private void processHit(JsonObject hit) throws Exception {
    JsonObject source = hit.get("_source").getAsJsonObject();

    try {
      // For each hit, create a new Avro record to serialize it into the new
      // format for storage.
      GenericRecord log = new GenericData.Record(schema.getSchema());
      log.put("id", hit.get("_id").getAsString());

      // Loop over each attribute in the source data, assigning each value to
      // the new data record.
      for (Map.Entry<String, JsonElement> entry : source.entrySet()) {
        String key = entry.getKey();

        // Skip this field if we've explicitly marked it as not migrating.
        if (App.SKIP_FIELDS.contains(key)) {
          continue;
        }

        JsonElement value = entry.getValue();

        // Skip setting anything if the value is null.
        if (value == null || value.isJsonNull()) {
          continue;
        }

        // Handle special processing for certain fields.
        switch (key) {
          case "request_at":
            // Split up the timestamp into several fields for better compatibility
            // with the Kylin's cube's that will be created (which doesn't support
            // timestamps yet).
            DateTime requestAt = this.parseTimestamp(value);
            log.put("timestamp_utc", requestAt.getMillis());
            log.put("timestamp_tz_offset", App.TIMEZONE.getOffset(requestAt.getMillis()));
            log.put("timestamp_tz_year", dateFormatter.print(requestAt.withDayOfYear(1)));
            log.put("timestamp_tz_month", dateFormatter.print(requestAt.withDayOfMonth(1)));
            log.put("timestamp_tz_week", dateFormatter.print(requestAt.withDayOfWeek(1)));
            log.put("timestamp_tz_date", dateFormatter.print(requestAt));
            log.put("timestamp_tz_hour", dateTimeFormatter
                .print(requestAt.withMinuteOfHour(0).withSecondOfMinute(0).withMillisOfSecond(0)));
            log.put("timestamp_tz_minute",
                dateTimeFormatter.print(requestAt.withSecondOfMinute(0).withMillisOfSecond(0)));
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
            // the best data possible and not losing anything in the process.
            URL url;
            try {
              url = new URL(value.getAsString());
            } catch (MalformedURLException e) {
              try {
                // Cleanup some oddities in some invalid URLs seen (I think from
                // localhost testing).
                url = new URL(value.getAsString().replace(":80:80/", ":80/").replace("://[", "://")
                    .replace("]/", "/"));
              } catch (MalformedURLException e2) {
                logger.error(hit.toString());
                throw (e2);
              }
            }

            // Store the original request_scheme, since that seems to be more
            // accurate than sometimes incorrect http:// urls on request_url that
            // are actually https.
            String requestScheme = source.get("request_scheme").getAsString();
            if (!url.getProtocol().equals(requestScheme)) {
              logger.warn("request_url's scheme (" + url.getProtocol()
                  + ") does not match request_scheme (" + requestScheme + ")");
            }
            log.put("request_url_scheme", requestScheme);

            // Store the host extracted from the full URL, since that seems more
            // accurate than the separate request_host field (it seems to better
            // handle some odd invalid hostnames, which probably don't actually
            // matter too much).
            String requestHost = source.get("request_host").getAsString().toLowerCase();
            String urlHost = url.getHost().toLowerCase();
            if (!urlHost.equals(requestHost)) {
              logger.warn("request_url's host (" + url.getHost() + ") does not match request_host ("
                  + requestHost + ")");
            }
            log.put("request_url_host", urlHost);

            // As a new field, store the port used. Most of the time this will be
            // the default 80 or 443, depending on the scheme.
            int urlPort = url.getPort();
            if (log.get("request_url_scheme").equals("https") && urlPort == 80) {
              log.put("request_url_port", 443);
            } else {
              // If the port isn't set, or it's 50090, set it to the default port
              // based on the scheme. We're ignoring port 50090, since this is
              // present on some of our rather old imported logs, and was an
              // internal-only port that was used (but was never public, so this
              // isn't accurate).
              if (urlPort == -1 || urlPort == 50090) {
                if (log.get("request_url_scheme").equals("https")) {
                  log.put("request_url_port", 443);
                } else {
                  log.put("request_url_port", 80);
                }
              } else {
                log.put("request_url_port", urlPort);
              }
            }

            // Store the path extracted from the full URL, since it seems to be
            // more accurate at dealing with odd URL encoding issues.
            String requestPath = source.get("request_path").getAsString();
            if (!url.getPath().equals(requestPath)) {
              // Before throwing a warning, ignore some semi-common URL encoding
              // differences between the full URL and the request_path field
              // (where we're comfortable with the encoding of the full URL's
              // version). Also deal with missing hash fragment details.
              String encodedUrlPath = url.getPath();
              if (url.getRef() != null && url.getQuery() == null) {
                encodedUrlPath += "#" + url.getRef();
              }
              encodedUrlPath = URLEncoder.encode(encodedUrlPath, "UTF-8");
              encodedUrlPath = encodedUrlPath.replace("%25", "%");

              String encodedRequestPath = requestPath.replaceAll("/(x[0-9])", "\\\\$1");
              encodedRequestPath = URLEncoder.encode(encodedRequestPath, "UTF-8");
              encodedRequestPath = encodedRequestPath.replace("%25", "%");

              if (!encodedUrlPath.equals(encodedRequestPath)) {
                logger.warn("request_url's path (" + url.getPath() + " - " + encodedUrlPath
                    + ") does not match request_path (" + requestPath + " - " + encodedRequestPath
                    + ")");
              }
            }
            log.put("request_url_path", url.getPath());

            String[] pathLevels = StringUtils.split(url.getPath(), "/", 6);
            for (int i = 0; i < pathLevels.length; i++) {
              String pathLevel = pathLevels[i];
              if (i < pathLevels.length - 1) {
                pathLevel = pathLevel + "/";
              }
              if (i == 0 && pathLevel != "/") {
                pathLevel = "/" + pathLevel;
              }
              log.put("request_url_path_level" + (i + 1), pathLevel);
            }

            // Store the query string extracted from the full URL.
            String requestQuery = url.getQuery();
            log.put("request_url_query", requestQuery);

            // If a hash fragment is present in the full URL, this is actually a
            // flag that something's fishy with the URL encoding, since our
            // server-side logs can't possible contain fragment information. So
            // we'll assume this information actually represents something
            // following a URL-encoded hash fragment, and append that to the
            // appropriate place.
            String urlRef = url.getRef();
            if (urlRef != null) {
              if (log.get("request_url_query") != null) {
                log.put("request_url_query", log.get("request_url_query") + "%23" + urlRef);
              } else {
                log.put("request_url_path", log.get("request_url_path") + "%23" + urlRef);
              }
            }

            // Re-assemble the URL based on all of our newly stored individual
            // componetns.
            String reassmbledUrl =
                log.get("request_url_scheme") + "://" + log.get("request_url_host");
            if (log.get("request_url_scheme").equals("http")) {
              if ((Integer) log.get("request_url_port") != 80) {
                reassmbledUrl = reassmbledUrl + ":" + log.get("request_url_port");
              }
            } else if (log.get("request_url_scheme").equals("https")) {
              if ((Integer) log.get("request_url_port") != 443) {
                reassmbledUrl = reassmbledUrl + ":" + log.get("request_url_port");
              }
            } else {
              reassmbledUrl = reassmbledUrl + ":" + log.get("request_url_port");
            }
            reassmbledUrl = reassmbledUrl + log.get("request_url_path");
            if (requestQuery != null) {
              reassmbledUrl = reassmbledUrl + "?" + log.get("request_url_query");
            }

            // As a last sanity check to make sure we're not throwing away data as
            // part of this migration, compare the original full URL string to the
            // new URL composed of the various parts.
            if (!value.getAsString().equals(reassmbledUrl)) {
              // Ignore some of the default ports for comparison.
              String compareUrl = value.getAsString().replaceFirst(":(80|443|50090)/", "/");

              // Ignore url encoding of the hash fragment.
              compareUrl = compareUrl.replaceFirst("#", "%23");

              // Ignore case-sensitivity on the Host.
              Pattern pattern = Pattern.compile("://(.+?)/");
              Matcher matcher = pattern.matcher(compareUrl);
              StringBuffer buffer = new StringBuffer();
              while (matcher.find()) {
                matcher.appendReplacement(buffer,
                    Matcher.quoteReplacement("://" + matcher.group(1).toLowerCase() + "/"));
              }
              matcher.appendTail(buffer);
              compareUrl = buffer.toString();

              if (!compareUrl.equals(reassmbledUrl)) {
                logger.warn("request_url (" + value.getAsString() + " - " + compareUrl
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

        // Handle empty strings values.
        if (value != null && value.isJsonPrimitive() && value.getAsJsonPrimitive().isString()
            && value.getAsJsonPrimitive().getAsString().equals("")) {
          switch (key) {
            // Replace empty string request_ips with 127.0.0.1. There's not a lot
            // of these empty string values, but since this is considered a
            // required field moving forward, let's make sure we have at least
            // some real value in there.
            case "request_ip":
              logger.warn(
                  key + " contains empty string value: replacing with 127.0.0.1 since NULLs are not allowed on this field: "
                      + hit);
              value = new JsonPrimitive("127.0.0.1");
              break;

            // Set empty string values to null.
            //
            // I think in all of our cases, nulls are more appropriate, we just
            // have empty strings in some of our source data due to various
            // migrations. Kylin (v1.2) also seems to treat empty strings as NULLs
            // in the rollups, so for consistency sake, we'll avoid them.
            default:
              value = null;
              break;
          }
        }

        if (value != null) {
          // Set the value on the new record, performing type-casting as needed.
          try {
            Schema.Type type = schema.getFieldType(key);
            if (type == Schema.Type.INT) {
              log.put(key, value.getAsInt());
            } else if (type == Schema.Type.LONG) {
              log.put(key, value.getAsLong());
            } else if (type == Schema.Type.DOUBLE) {
              log.put(key, value.getAsDouble());
            } else if (type == Schema.Type.BOOLEAN) {
              log.put(key, value.getAsBoolean());
            } else {
              try {
                log.put(key, value.getAsString());
              } catch (IllegalStateException e) {
                // Handle some unexpected array types by comma-delimiting the
                // values.
                if (value.isJsonArray()) {
                  StringBuffer buffer = new StringBuffer();
                  Iterator<JsonElement> iter = value.getAsJsonArray().iterator();
                  while (iter.hasNext()) {
                    buffer.append(iter.next().getAsString());
                    if (iter.hasNext()) {
                      buffer.append(", ");
                    }
                  }
                  log.put(key, buffer.toString());
                } else {
                  throw (e);
                }
              }
            }
          } catch (Exception e) {
            logger.error("Eror on field: " + key);
            logger.error(e.getMessage());
            throw (e);
          }
        }
      }

      OrcRow orcRecord = new OrcRow(schema.getNonPartitionFieldsList().size());
      for (int i = 0; i < schema.getNonPartitionFieldsList().size(); i++) {
        String field = schema.getNonPartitionFieldsList().get(i);
        Schema.Type type = schema.getFieldType(field);
        Object rawValue = log.get(field);
        Object value;

        if (rawValue != null) {
          if (type == Schema.Type.INT) {
            if (schema.isFieldTypeShort(field)) {
              value = new ShortWritable(((Integer) rawValue).shortValue());
            } else {
              value = new IntWritable((int) rawValue);
            }
          } else if (type == Schema.Type.LONG) {
            value = new LongWritable((long) rawValue);
          } else if (type == Schema.Type.DOUBLE) {
            value = new DoubleWritable((double) rawValue);
          } else if (type == Schema.Type.BOOLEAN) {
            value = new BooleanWritable((boolean) rawValue);
          } else if (type == Schema.Type.STRING) {
            value = new Text((String) rawValue);
          } else {
            throw new IOException("Unknown type: " + type.toString());
          }

          orcRecord.setFieldValue(i, value);
        }
      }

      this.getOrcWriter().addRow(orcRecord);
    } catch (Exception e) {
      logger.error("Error on hit: " + hit);
      logger.error(e.getMessage());
      throw (e);
    }
  }

  private DateTime parseTimestamp(JsonElement value) {
    DateTime date;
    if (value.getAsJsonPrimitive().isNumber()) {
      date = new DateTime(value.getAsLong(), DateTimeZone.UTC);
    } else {
      date = this.dateTimeParser.parseDateTime(value.getAsString());
    }
    return date.withZone(App.TIMEZONE);
  }
}
