package apiumbrella.hadoop_analytics;

import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.FileStatus;
import org.apache.hadoop.fs.FileSystem;
import org.apache.hadoop.fs.LocatedFileStatus;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.fs.RemoteIterator;
import org.joda.time.DateTime;
import org.joda.time.DateTimeZone;
import org.joda.time.format.DateTimeFormatter;
import org.joda.time.format.ISODateTimeFormat;
import org.quartz.CronScheduleBuilder;
import org.quartz.JobBuilder;
import org.quartz.JobDetail;
import org.quartz.Scheduler;
import org.quartz.SchedulerException;
import org.quartz.SimpleScheduleBuilder;
import org.quartz.Trigger;
import org.quartz.TriggerBuilder;
import org.quartz.impl.StdSchedulerFactory;
import org.slf4j.Logger;

public class App {
  private static boolean DISABLE_LIVE_DATA_CONVERSION =
      Boolean.getBoolean("apiumbrella.disable_live_data_conversion");
  private static boolean DISABLE_KYLIN_REFRESH =
      Boolean.getBoolean("apiumbrella.disable_kylin_refresh");
  protected static DateTimeZone TIMEZONE =
      DateTimeZone.forID(System.getProperty("apiumbrella.timezone", "UTC"));
  protected static final String HDFS_URI =
      System.getProperty("apiumbrella.hdfs_uri", "hdfs://127.0.0.1:8020");
  protected static final String HDFS_ROOT = "/apps/api-umbrella";
  protected static final String HDFS_LOGS_ROOT = HDFS_ROOT + "/logs";
  protected static final String HDFS_LOGS_LIVE_ROOT = App.HDFS_ROOT + "/logs-live";
  protected static final String LOGS_TABLE_NAME = "api_umbrella.logs";
  protected static final String LOGS_LIVE_TABLE_NAME = "api_umbrella.logs_live";

  public void run() throws SchedulerException {
    Scheduler scheduler = StdSchedulerFactory.getDefaultScheduler();
    scheduler.start();

    if (!DISABLE_LIVE_DATA_CONVERSION) {
      /*
       * Job to convert the live log data (coming from Kafka & Flume) into the ORC files for
       * querying and long-term storage.
       */
      JobDetail convertJob = JobBuilder.newJob(ConvertLiveDataToOrc.class)
          .withIdentity("convertLiveDataJob").usingJobData("lastMigratedPartitionTime", 0L)
          .usingJobData("lastConcatenateTime", 0L).usingJobData("tablesCreated", false).build();
      /* Run every 30 seconds */
      Trigger convertTrigger =
          TriggerBuilder.newTrigger().withIdentity("convertLiveDataTrigger").startNow()
              .withSchedule(
                  SimpleScheduleBuilder.simpleSchedule().withIntervalInSeconds(30).repeatForever())
              .build();
      scheduler.scheduleJob(convertJob, convertTrigger);
    }

    if (!DISABLE_KYLIN_REFRESH) {
      /* Job to process the new log data into the pre-aggregated Kylin cubes. */
      JobDetail refreshJob = JobBuilder.newJob(RefreshKylin.class).withIdentity("refreshKylinJob")
          .storeDurably().build();
      /*
       * Run this job once immediately on boot to catch up with any new data that needs processing.
       */
      Trigger refreshImmediateTrigger = TriggerBuilder.newTrigger()
          .withIdentity("refreshKylinImmediateTrigger").forJob(refreshJob).startNow()
          .withSchedule(SimpleScheduleBuilder.simpleSchedule()).build();
      /*
       * After the initial run, run this every morning at 01:00 in the timezone used for data. This
       * assumes that by 01:00 there will no longer be any data writing to the previous day's
       * partition, so it's safe to fully process that day into Kylin.
       */
      Trigger refreshDailyTrigger = TriggerBuilder.newTrigger()
          .withIdentity("refreshKylinDailyTrigger").forJob(refreshJob).startNow()
          .withSchedule(
              CronScheduleBuilder.dailyAtHourAndMinute(1, 0).inTimeZone(TIMEZONE.toTimeZone()))
          .build();
      scheduler.addJob(refreshJob, false);
      scheduler.scheduleJob(refreshImmediateTrigger);
      scheduler.scheduleJob(refreshDailyTrigger);
    }

    scheduler.start();
  }

  public static void main(String[] args) throws SchedulerException {
    if (System.getProperty("apiumbrella.root_log_level") == null) {
      System.setProperty("apiumbrella.root_log_level", "WARN");
    }

    if (System.getProperty("apiumbrella.log_level") == null) {
      System.setProperty("apiumbrella.log_level", "INFO");
    }

    App app = new App();
    app.run();
  }

  public static FileSystem getHadoopFileSystem() throws IOException, URISyntaxException {
    Configuration conf = new Configuration();
    conf.setInt("ipc.client.connect.max.retries.on.timeouts", 3);
    /* Fix for hadoop jar ordering: http://stackoverflow.com/a/21118824 */
    conf.set("fs.hdfs.impl", org.apache.hadoop.hdfs.DistributedFileSystem.class.getName());
    conf.set("fs.file.impl", org.apache.hadoop.fs.LocalFileSystem.class.getName());

    return FileSystem.get(new URI(HDFS_URI), conf);
  }

  public static Connection getHiveConnection() throws ClassNotFoundException, SQLException {
    /* Load the Hive JDBC class. */
    Class.forName("org.apache.hive.jdbc.HiveDriver");

    return DriverManager.getConnection("jdbc:hive2://localhost:10000/api_umbrella", "hive", "");
  }

  /**
   * Find any partitions in the api_umbrella.logs table that are composed of more than 1 file and
   * concatenate the partitions to merge them down to 1 file. This helps improve query performance
   * on the historical data.
   * 
   * @param logger
   * @throws ClassNotFoundException
   * @throws SQLException
   * @throws IOException
   * @throws IllegalArgumentException
   * @throws URISyntaxException
   */
  public static synchronized void concatenateTablePartitions(Logger logger)
      throws ClassNotFoundException, SQLException, IOException, IllegalArgumentException,
      URISyntaxException {
    logger.debug("Begin concatenate table partitions");

    /* Build the CONCATENATE SQL command. */
    LogSchema logSchema = new LogSchema();
    StringBuilder sql = new StringBuilder();
    sql.append("ALTER TABLE " + App.LOGS_TABLE_NAME + " PARTITION(");
    for (int i = 0; i < logSchema.getPartitionFieldsList().size(); i++) {
      if (i > 0) {
        sql.append(",");
      }
      sql.append(logSchema.getPartitionFieldsList().get(i) + "=?");
    }
    sql.append(") CONCATENATE");

    /*
     * Iterate over all the partition files to detect partitions that contain more than 1 file.
     */
    RemoteIterator<LocatedFileStatus> filesIter =
        getHadoopFileSystem().listFiles(new Path(HDFS_URI + HDFS_LOGS_ROOT), true);
    Pattern partitionDatePattern = Pattern.compile(".*timestamp_tz_date=(\\d{4}-\\d{2}-\\d{2})");
    HashMap<DateTime, Integer> partitionFileCounts = new HashMap<DateTime, Integer>();
    while (filesIter.hasNext()) {
      FileStatus file = filesIter.next();
      Path partition = file.getPath().getParent();
      Matcher matcher = partitionDatePattern.matcher(partition.toString());
      DateTime partitionTime = null;
      while (matcher.find()) {
        partitionTime = new DateTime(matcher.group(1) + "T00:00:00");
      }

      Integer count = partitionFileCounts.get(partitionTime);
      if (count == null) {
        count = 0;
      }
      partitionFileCounts.put(partitionTime, count + 1);
    }

    /*
     * Iterate over all the partitions with more than 1 file and run the concatenate command against
     * them.
     */
    Connection connection = null;
    DateTimeFormatter dateFormatter = ISODateTimeFormat.date();
    for (Map.Entry<DateTime, Integer> entry : partitionFileCounts.entrySet()) {
      DateTime partition = entry.getKey();
      Integer count = entry.getValue();
      logger.debug("Partition " + partition + ": " + count + " files");
      if (count > 1) {
        if (connection == null) {
          connection = getHiveConnection();
        }

        logger.info("Concatenating table partition " + partition + " (" + count + " files)");
        PreparedStatement concatenate = connection.prepareStatement(sql.toString());
        concatenate.setString(1, dateFormatter.print(partition.withDayOfYear(1)));
        concatenate.setString(2, dateFormatter.print(partition.withDayOfMonth(1)));
        concatenate.setString(3, dateFormatter.print(partition.withDayOfWeek(1)));
        concatenate.setString(4, dateFormatter.print(partition));
        concatenate.executeUpdate();
        concatenate.close();
      }
    }

    logger.debug("Finish concatenate table partitions");
  }
}
