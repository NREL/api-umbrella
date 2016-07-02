package apiumbrella.hadoop_analytics;

import java.io.BufferedWriter;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.net.URISyntaxException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.TreeSet;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.apache.commons.io.IOUtils;
import org.apache.hadoop.fs.FSDataInputStream;
import org.apache.hadoop.fs.FSDataOutputStream;
import org.apache.hadoop.fs.FileStatus;
import org.apache.hadoop.fs.FileSystem;
import org.apache.hadoop.fs.LocatedFileStatus;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.fs.RemoteIterator;
import org.joda.time.DateTime;
import org.joda.time.format.DateTimeFormat;
import org.joda.time.format.DateTimeFormatter;
import org.joda.time.format.ISODateTimeFormat;
import org.quartz.DisallowConcurrentExecution;
import org.quartz.Job;
import org.quartz.JobDataMap;
import org.quartz.JobExecutionContext;
import org.quartz.JobExecutionException;
import org.quartz.PersistJobDataAfterExecution;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * This class is responsible for migrating the live log data into permanent ORC storage (with likely
 * a 2-3 minute delay).
 * 
 * Live log data is sent by the application servers in the following fashion:
 * 
 * [nginx] --json--> [rsyslog] --json--> [flume] --json--> [hdfs]
 * 
 * Flume stores the JSON files in directories partitioned by minute. This background job then runs
 * periodically to migrate this per-minute JSON data into the permanent ORC storage. The data is
 * migrated by appending each minute's data to the ORC table, which is partitioned by day. With this
 * approach, it may take around 2-3 minutes for the data to become populated in the ORC table (since
 * we have to wait until we're sure the minute partition is no longer being written to).
 * 
 * Note: A cleaner and more live solution would involve populating the ORC table directly using Hive
 * transaction streaming: https://cwiki.apache.org/confluence/display/Hive/Streaming+Data+Ingest
 * However, since we're on Hive 0.14 (for Kylin & HDP 2.2 compatibility), there are several bugs in
 * the Hive streaming implementation that impact us
 * (https://issues.apache.org/jira/browse/HIVE-8966,
 * https://issues.apache.org/jira/browse/HIVE-11540,
 * https://issues.apache.org/jira/browse/HIVE-5143), and Flume's Hive integration is also currently
 * experimental (I've run into some issues and high memory use with it). So for now, we'll use this
 * more manual approach that can work with the older version of Hive, but in the future this may be
 * worth revisiting.
 */
@DisallowConcurrentExecution
@PersistJobDataAfterExecution
public class ConvertLiveDataToOrc implements Job {
  private static final Path LAST_MIGRATED_MARKER =
      new Path(App.HDFS_URI + App.HDFS_ROOT + "/.logs-live-last-migrated-partition-time");
  final Logger logger;

  Pattern partitionDatePattern = Pattern.compile(
      ".*timestamp_tz_date=(\\d{4}-\\d{2}-\\d{2})/timestamp_tz_hour_minute=(\\d{2})-(\\d{2}).*");
  DateTimeFormatter dateFormatter = ISODateTimeFormat.date();
  DateTimeFormatter hourMinuteFormatter = DateTimeFormat.forPattern("HH-mm");
  private static LogSchema logSchema = new LogSchema();
  private static String createExternalTableSql;
  private static String createLiveExternalTableSql;
  private static String addPartitionSql;
  private static String addLivePartitionSql;
  private static String dropLivePartitionSql;
  private static String insertAppendSql;
  private static String insertOverwriteSql;
  private FileSystem fileSystem;
  private long lastMigratedPartitionTime = 0;

  public ConvertLiveDataToOrc() {
    logger = LoggerFactory.getLogger(this.getClass());
    logger.debug("Initializing " + this.getClass());
  }

  public void execute(JobExecutionContext context) throws JobExecutionException {
    try {
      run(context);
    } catch (Exception e) {
      logger.error("Convert live data to ORC error", e);
      JobExecutionException jobError = new JobExecutionException(e);
      throw jobError;
    }
  }

  public void run(JobExecutionContext context) throws SQLException, IOException,
      ClassNotFoundException, IllegalArgumentException, URISyntaxException {
    logger.debug("Begin processing");

    JobDataMap jobData = context.getJobDetail().getJobDataMap();
    lastMigratedPartitionTime = jobData.getLong("lastMigratedPartitionTime");

    fileSystem = App.getHadoopFileSystem();
    if (lastMigratedPartitionTime == 0) {
      if (fileSystem.exists(LAST_MIGRATED_MARKER)) {
        FSDataInputStream markerInputStream = fileSystem.open(LAST_MIGRATED_MARKER);
        lastMigratedPartitionTime = Long.parseLong(IOUtils.toString(markerInputStream), 10);
        logger.debug("Read last migrated partition timestamp marker: " + lastMigratedPartitionTime);
      }
    }

    Connection connection = null;
    try {
      connection = App.getHiveConnection();
      createTables(jobData, connection);

      for (DateTime partition : getInactivePartitions()) {
        if (partition.getMillis() > lastMigratedPartitionTime) {
          logger.info("Migrating partition: " + partition);

          PreparedStatement addPartition = connection.prepareStatement(getAddPartitionSql());
          addPartition.setString(1, dateFormatter.print(partition.withDayOfYear(1)));
          addPartition.setString(2, dateFormatter.print(partition.withDayOfMonth(1)));
          addPartition.setString(3, dateFormatter.print(partition.withDayOfWeek(1)));
          addPartition.setString(4, dateFormatter.print(partition));
          addPartition.executeUpdate();
          addPartition.close();

          PreparedStatement addLivePartition =
              connection.prepareStatement(getAddLivePartitionSql());
          addLivePartition.setString(1, dateFormatter.print(partition));
          addLivePartition.setString(2, hourMinuteFormatter.print(partition));
          addLivePartition.executeUpdate();
          addLivePartition.close();

          PreparedStatement migrate = connection.prepareStatement(getInsertAppendSql());
          migrate.setString(1, dateFormatter.print(partition.withDayOfYear(1)));
          migrate.setString(2, dateFormatter.print(partition.withDayOfMonth(1)));
          migrate.setString(3, dateFormatter.print(partition.withDayOfWeek(1)));
          migrate.setString(4, dateFormatter.print(partition));
          migrate.setString(5, dateFormatter.print(partition));
          migrate.setString(6, hourMinuteFormatter.print(partition));
          migrate.executeUpdate();
          migrate.close();

          lastMigratedPartitionTime = partition.getMillis();
          jobData.put("lastMigratedPartitionTime", lastMigratedPartitionTime);

          FSDataOutputStream markerOutputStream = fileSystem.create(LAST_MIGRATED_MARKER, true);
          BufferedWriter br = new BufferedWriter(new OutputStreamWriter(markerOutputStream));
          br.write(Long.toString(lastMigratedPartitionTime));
          br.close();
        } else {
          logger.debug("Skipping already processed partition: " + partition);
        }
      }

      jobData.put("lastMigratedPartitionTime", lastMigratedPartitionTime);

      /*
       * Since we're appending the live data to the ORC files every minute, we end up with many
       * small ORC files in the api_umbrella.logs partitions. To help improve query performance,
       * concatenate the table partitions ever 1 hour (which merges the existing files down to a
       * single file).
       */
      long now = DateTime.now().getMillis();
      long lastConcatenateTime = jobData.getLong("lastConcatenateTime");
      if (now - lastConcatenateTime > 1 * 60 * 60 * 1000) {
        App.concatenateTablePartitions(logger);
        jobData.put("lastConcatenateTime", now);
      }
    } finally {
      if (connection != null) {
        connection.close();
      }
    }

    logger.debug("Finish processing");
  }

  /**
   * Create either of the external tables
   * 
   * @param connection
   * @throws SQLException
   */
  private void createTables(JobDataMap jobData, Connection connection) throws SQLException {
    boolean tablesCreated = jobData.getBoolean("tablesCreated");
    if (tablesCreated == false) {
      Statement statement = connection.createStatement();

      logger.info("Creating table (if not exists): " + App.LOGS_TABLE_NAME);
      statement.executeUpdate(getCreateExternalTableSql());

      logger.info("Creating table (if not exists): " + App.LOGS_LIVE_TABLE_NAME);
      statement.executeUpdate(getCreateLiveExternalTableSql());

      statement.close();
      jobData.put("tablesCreated", true);
    }
  }

  /**
   * Generate the SQL string for creating the external "api_umbrella.logs" table in Hive. This is
   * the table that stores all the data in the definitive format used for queries and processing.
   * 
   * The columns are generated based on the Avro schema definition (src/main/resources/log.avsc) for
   * our log data to ensure the schemas match across the different tables.
   * 
   * @return
   */
  private static String getCreateExternalTableSql() {
    if (createExternalTableSql == null) {
      StringBuilder sql = new StringBuilder();
      sql.append("CREATE EXTERNAL TABLE IF NOT EXISTS " + App.LOGS_TABLE_NAME + "(");
      for (int i = 0; i < logSchema.getNonPartitionFieldsList().size(); i++) {
        if (i > 0) {
          sql.append(",");
        }
        String field = logSchema.getNonPartitionFieldsList().get(i);
        sql.append(field + " " + logSchema.getFieldHiveType(field));
      }
      sql.append(") ");

      sql.append("PARTITIONED BY(");
      for (int i = 0; i < logSchema.getPartitionFieldsList().size(); i++) {
        if (i > 0) {
          sql.append(",");
        }
        String field = logSchema.getPartitionFieldsList().get(i);
        sql.append(field + " " + logSchema.getFieldHiveType(field));
      }
      sql.append(") ");

      sql.append("STORED AS ORC LOCATION '" + App.HDFS_LOGS_ROOT + "'");

      createExternalTableSql = sql.toString();
    }

    return createExternalTableSql;
  }

  /**
   * Generate the SQL string for creating the external "api_umbrella.logs_live" table in Hive. This
   * is the table that stores temporary data, partitioned by minute, that Flume is writing to HDFS
   * JSON files to.
   * 
   * The columns are generated based on the Avro schema definition (src/main/resources/log.avsc) for
   * our log data to ensure the schemas match across the different tables.
   * 
   * @return
   */
  private static String getCreateLiveExternalTableSql() {
    if (createLiveExternalTableSql == null) {
      StringBuilder sql = new StringBuilder();
      sql.append("CREATE EXTERNAL TABLE IF NOT EXISTS " + App.LOGS_LIVE_TABLE_NAME + "(");
      for (int i = 0; i < logSchema.getLiveNonPartitionFieldsList().size(); i++) {
        if (i > 0) {
          sql.append(",");
        }
        String field = logSchema.getLiveNonPartitionFieldsList().get(i);
        sql.append(field + " " + logSchema.getFieldHiveType(field));
      }
      sql.append(") ");

      sql.append("PARTITIONED BY(");
      for (int i = 0; i < logSchema.getLivePartitionFieldsList().size(); i++) {
        if (i > 0) {
          sql.append(",");
        }
        String field = logSchema.getLivePartitionFieldsList().get(i);
        sql.append(field + " " + logSchema.getFieldHiveType(field));
      }
      sql.append(") ");

      sql.append("ROW FORMAT SERDE 'org.apache.hive.hcatalog.data.JsonSerDe' ");
      sql.append("STORED AS TEXTFILE LOCATION '" + App.HDFS_LOGS_LIVE_ROOT + "'");

      createLiveExternalTableSql = sql.toString();
    }

    return createLiveExternalTableSql;
  }

  /**
   * Generate the SQL string for adding new date partitions to the "api_umbrella.logs" table.
   * 
   * @return
   */
  private static String getAddPartitionSql() {
    if (addPartitionSql == null) {
      StringBuilder sql = new StringBuilder();
      sql.append("ALTER TABLE " + App.LOGS_TABLE_NAME + " ADD IF NOT EXISTS ");
      sql.append("PARTITION(");
      for (int i = 0; i < logSchema.getPartitionFieldsList().size(); i++) {
        if (i > 0) {
          sql.append(",");
        }
        sql.append(logSchema.getPartitionFieldsList().get(i) + "=?");
      }
      sql.append(")");

      addPartitionSql = sql.toString();
    }

    return addPartitionSql;
  }

  /**
   * Generate the SQL string for adding new minute partitions to the "api_umbrella.logs_live" table.
   * 
   * @return
   */
  private static String getAddLivePartitionSql() {
    if (addLivePartitionSql == null) {
      StringBuilder sql = new StringBuilder();
      sql.append("ALTER TABLE " + App.LOGS_LIVE_TABLE_NAME + " ADD IF NOT EXISTS ");
      sql.append("PARTITION(");
      for (int i = 0; i < logSchema.getLivePartitionFieldsList().size(); i++) {
        if (i > 0) {
          sql.append(",");
        }
        sql.append(logSchema.getLivePartitionFieldsList().get(i) + "=?");
      }
      sql.append(")");

      addLivePartitionSql = sql.toString();
    }

    return addLivePartitionSql;
  }

  protected static String getDropLivePartitionsDaySql() {
    if (dropLivePartitionSql == null) {
      StringBuilder sql = new StringBuilder();
      sql.append("ALTER TABLE " + App.LOGS_TABLE_NAME + " DROP IF EXISTS ");
      sql.append("PARTITION(timestamp_tz_date=?)");

      dropLivePartitionSql = sql.toString();
    }

    return dropLivePartitionSql;
  }

  /**
   * Generate the SQL string that copies a minute worth of data from the "api_umbrella.logs_live"
   * table (JSON storage) to the real "api_umbrella.logs" table (ORC storage).
   * 
   * Data is appended to the ORC table's full-day partition, so it's expected that this will run
   * repeatedly for each new minute of data, but the same minute should not be repeated (or else the
   * same data will be appended twice to the ORC table).
   * 
   * @return
   */
  private static String getInsertAppendSql() {
    if (insertAppendSql == null) {
      StringBuilder sql = new StringBuilder();
      sql.append("INSERT INTO TABLE " + App.LOGS_TABLE_NAME + " ");

      sql.append("PARTITION(");
      for (int i = 0; i < logSchema.getPartitionFieldsList().size(); i++) {
        if (i > 0) {
          sql.append(",");
        }
        sql.append(logSchema.getPartitionFieldsList().get(i) + "=?");
      }
      sql.append(") ");

      sql.append("SELECT ");
      for (int i = 0; i < logSchema.getNonPartitionFieldsList().size(); i++) {
        if (i > 0) {
          sql.append(",");
        }
        sql.append(logSchema.getNonPartitionFieldsList().get(i));
      }

      sql.append(" FROM " + App.LOGS_LIVE_TABLE_NAME + " WHERE ");
      for (int i = 0; i < logSchema.getLivePartitionFieldsList().size(); i++) {
        if (i > 0) {
          sql.append(" AND ");
        }
        sql.append(logSchema.getLivePartitionFieldsList().get(i) + "=?");
      }
      sql.append(" ORDER BY timestamp_utc, id");

      insertAppendSql = sql.toString();
    }

    return insertAppendSql;
  }

  protected static String getInsertOverwriteDaySql() {
    if (insertOverwriteSql == null) {
      StringBuilder sql = new StringBuilder();
      sql.append("INSERT OVERWRITE TABLE " + App.LOGS_TABLE_NAME + " ");

      sql.append("PARTITION(");
      for (int i = 0; i < logSchema.getPartitionFieldsList().size(); i++) {
        if (i > 0) {
          sql.append(",");
        }
        sql.append(logSchema.getPartitionFieldsList().get(i) + "=?");
      }
      sql.append(") ");

      sql.append("SELECT DISTINCT ");
      for (int i = 0; i < logSchema.getNonPartitionFieldsList().size(); i++) {
        if (i > 0) {
          sql.append(",");
        }
        sql.append(logSchema.getNonPartitionFieldsList().get(i));
      }

      sql.append(" FROM " + App.LOGS_LIVE_TABLE_NAME + " WHERE timestamp_tz_date=?");
      sql.append(" ORDER BY timestamp_utc, id");

      insertOverwriteSql = sql.toString();
    }

    return insertOverwriteSql;
  }

  /**
   * Return all the minute partitions within the "api-umbrella.logs_live" table that are no longer
   * being written to.
   * 
   * This is determined by looking at all of the underlying HDFS files that Flume is writing to and
   * seeing which partitions haven't been touched in over 1 minute.
   * 
   * @return
   * @throws IOException
   */
  private TreeSet<DateTime> getInactivePartitions() throws IOException {
    RemoteIterator<LocatedFileStatus> filesIter =
        fileSystem.listFiles(new Path(App.HDFS_URI + App.HDFS_LOGS_LIVE_ROOT), true);

    TreeSet<DateTime> inactivePartitions = new TreeSet<DateTime>();
    TreeSet<DateTime> activePartitions = new TreeSet<DateTime>();
    long inactiveTimeThreshold = new DateTime().minusMinutes(1).getMillis();
    while (filesIter.hasNext()) {
      FileStatus file = filesIter.next();
      Path partition = file.getPath().getParent();
      Matcher matcher = partitionDatePattern.matcher(partition.toString());
      DateTime partitionTime = null;
      while (matcher.find()) {
        partitionTime = new DateTime(
            matcher.group(1) + "T" + matcher.group(2) + ":" + matcher.group(3) + ":00");
      }

      /*
       * If the file was recently written to, mark the partition as active (since we don't want to
       * touch it until we're sure no more data will show up in it).
       */
      if (file.getModificationTime() > inactiveTimeThreshold) {
        activePartitions.add(partitionTime);
      } else {
        /*
         * If the file is older, but currently being written to (denoted by Flume prefixing the file
         * with an "_" so it's ignored from Hive), then we also want to ignore it. However, this
         * case should be rare, since it would indicate Flume is writing to an older file than we
         * expect.
         */
        if (file.getPath().getName().startsWith("_")) {
          activePartitions.add(partitionTime);
        } else {
          inactivePartitions.add(partitionTime);
        }
      }
    }

    /*
     * Loop through all the active partitions and ensure that none of these are also marked as
     * inactive. This handles situations where the partition might have some older files, but other
     * files still being written to.
     */
    for (DateTime activePartition : activePartitions) {
      logger.debug("Active partition being written to: " + activePartition);
      inactivePartitions.remove(activePartition);

      /*
       * If data is unexpectedly coming in out-of-order, log this as an error, since this must
       * manually be dealt with.
       */
      if (activePartition.getMillis() < lastMigratedPartitionTime) {
        logger.warn("Partition with active files is unexpectedly older than the most recently "
            + "processed data. This means older data is being populated in the live data files. "
            + "This should be resolved during the nightly OVERWRITE refresh process. "
            + "Partition: " + activePartition);
      }
    }

    return inactivePartitions;
  }
}
