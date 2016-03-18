package apiumbrella.hadoop_analytics;

import java.io.IOException;
import java.io.InputStream;
import java.math.BigInteger;
import java.nio.file.Paths;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map.Entry;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.apache.avro.Schema;
import org.joda.time.DateTime;
import org.joda.time.DateTimeZone;
import org.joda.time.Period;
import org.joda.time.format.DateTimeFormatter;
import org.joda.time.format.ISODateTimeFormat;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.gson.JsonElement;

import io.searchbox.client.JestClient;
import io.searchbox.client.JestClientFactory;
import io.searchbox.client.JestResult;
import io.searchbox.client.config.HttpClientConfig;
import io.searchbox.indices.aliases.GetAliases;

public class App {
  protected static String DIR = System.getProperty("apiumbrella.dir",
    Paths.get("/tmp", "api-umbrella-logs").toString());
  protected static String ELASTICSEARCH_URL = System.getProperty("apiumbrella.elasticsearch_url",
    "http://localhost:9200");
  protected static int PAGE_SIZE = Integer
    .parseInt(System.getProperty("apiumbrella.page_size", "5000"));
  protected static int CONCURRENCY = Integer
    .parseInt(System.getProperty("apiumbrella.concurrency", "4"));
  protected static String START_DATE = System.getProperty("apiumbrella.start_date");
  protected static String END_DATE = System.getProperty("apiumbrella.end_date");
  protected static DateTimeZone TIMEZONE = DateTimeZone.forID(System.getProperty("apiumbrella.timezone", "UTC"));

  // Define fields we won't migrate to the new database.
  protected static final Set<String> SKIP_FIELDS = new HashSet<String>(Arrays.asList(new String[] {
    // These URL-related fields are handled specially when dealing with the
    // request_url field.
    "request_scheme",
    "request_host",
    "request_path",
    "request_query",

    // We're no longer storing the special hierarchy field.
    "request_hierarchy",
    "request_path_hierarchy",

    // We're only storing the user_id, and not other fields that can be derived
    // from it (lookups on these fields will need to first query the user table,
    // and then perform queries base don user_id).
    "user_registration_source",
    "user_email",
    "api_key",

    // Old timer field from the nodejs stack, that's not relevant anymore, and
    // we don't need to migrate over (it was always somewhat duplicative).
    "internal_response_time",

    // Junk field we've seen on some old data.
    "_type" }));

  final Logger logger = LoggerFactory.getLogger(App.class);

  private Schema schema;
  private HashMap<String, Schema.Type> schemaFieldTypes;
  private HashSet<String> schemaIntFields;
  private HashSet<String> schemaDoubleFields;
  private HashSet<String> schemaBooleanFields;
  private BigInteger globalHits = BigInteger.valueOf(0);

  public App() {
    ExecutorService executor = Executors.newFixedThreadPool(CONCURRENCY);

    DateTime date = this.getStartDate();
    DateTime endDate = this.getEndDate();
    getSchema();
    detectSchemaFields();
    while(date.isBefore(endDate)) {
      Runnable worker = new DayWorker(this, date);
      executor.execute(worker);

      date = date.plus(Period.days(1));
    }

    executor.shutdown();
    while(!executor.isTerminated()) {
    }
    logger.info("Finished all threads");
  }

  protected Schema getSchema() {
    if(this.schema == null) {
      InputStream is = App.class.getClassLoader().getResourceAsStream("log.avsc");
      try {
        this.schema = new Schema.Parser().parse(is);
      } catch(IOException e) {
        e.printStackTrace();
        System.exit(1);
      }
    }
    return this.schema;
  }

  protected HashMap<String, Schema.Type> getSchemaFieldTypes() {
    return this.schemaFieldTypes;
  }

  protected HashSet<String> getSchemaIntFields() {
    return this.schemaIntFields;
  }

  protected HashSet<String> getSchemaDoubleFields() {
    return this.schemaDoubleFields;
  }

  protected HashSet<String> getSchemaBooleanFields() {
    return this.schemaBooleanFields;
  }

  private void detectSchemaFields() {
    this.schemaFieldTypes = new HashMap<String, Schema.Type>();
    this.schemaIntFields = new HashSet<String>();
    this.schemaDoubleFields = new HashSet<String>();
    this.schemaBooleanFields = new HashSet<String>();

    for(Schema.Field field : getSchema().getFields()) {
      Schema.Type type = field.schema().getType();
      if(type == Schema.Type.UNION) {
        for(Schema unionSchema : field.schema().getTypes()) {
          if(unionSchema.getType() != Schema.Type.NULL) {
            type = unionSchema.getType();
            break;
          }
        }
      }

      this.schemaFieldTypes.put(field.name(), type);
      if(type == Schema.Type.INT) {
        this.schemaIntFields.add(field.name());
      } else if(type == Schema.Type.DOUBLE) {
        this.schemaDoubleFields.add(field.name());
      } else if(type == Schema.Type.BOOLEAN) {
        this.schemaBooleanFields.add(field.name());
      }
    }
  }

  protected synchronized BigInteger incrementGlobalHits(Integer total) {
    this.globalHits = this.globalHits.add(BigInteger.valueOf(total));
    return this.globalHits;
  }

  private DateTime getStartDate() {
    if(START_DATE != null) {
      DateTimeFormatter dateParser = ISODateTimeFormat.dateParser();
      return dateParser.parseDateTime(START_DATE);
    }

    JestClientFactory factory = new JestClientFactory();
    factory.setHttpClientConfig(
      new HttpClientConfig.Builder(ELASTICSEARCH_URL).multiThreaded(true).build());
    GetAliases aliases = new GetAliases.Builder().build();
    JestClient client = factory.getObject();
    DateTime first = null;
    try {
      JestResult result = client.execute(aliases);
      if(!result.isSucceeded()) {
        logger.error(result.getErrorMessage());
        System.exit(1);
      }

      for(Entry<String, JsonElement> entry : result.getJsonObject().entrySet()) {
        Pattern pattern = Pattern.compile("^api-umbrella.*-([0-9]{4})-([0-9]{2})$");
        Matcher matches = pattern.matcher(entry.getKey());
        if(matches.find()) {
          DateTime indexDate = new DateTime(Integer.parseInt(matches.group(1)),
            Integer.parseInt(matches.group(2)), 1, 0, 0, 0, DateTimeZone.UTC);
          if(first == null || indexDate.isBefore(first)) {
            first = indexDate;
          }
        }
      }
    } catch(IOException e) {
      e.printStackTrace();
      System.exit(1);
    }

    return first;
  }

  private DateTime getEndDate() {
    if(END_DATE != null) {
      DateTimeFormatter dateParser = ISODateTimeFormat.dateParser();
      return dateParser.parseDateTime(END_DATE);
    }

    return new DateTime();
  }

  public static void main(String[] args) throws SecurityException, IOException {
    // Setup defaults for logging to migrate.log.
    System.setProperty("org.slf4j.simpleLogger.logFile", "migrate.log");
    System.setProperty("org.slf4j.simpleLogger.defaultLogLevel", "warn");
    System.setProperty("org.slf4j.simpleLogger.log.gov.nrel.apiumbrella", "info");
    System.setProperty("org.slf4j.simpleLogger.showDateTime", "true");
    System.setProperty("org.slf4j.simpleLogger.dateTimeFormat", "yyyy-MM-dd'T'HH:mm:ss.SSSZ");
    System.setProperty("org.slf4j.simpleLogger.showLogName", "false");

    System.out.println("Logging to migrate.log...");

    new App();
  }
}
