package apiumbrella.hadoop_analytics;

import java.io.BufferedWriter;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.net.URI;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.TreeSet;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.apache.commons.io.IOUtils;
import org.apache.hadoop.conf.Configuration;
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
import org.slf4j.Logger;

/**
 * This class is responsible for migrating the live log data into permanent ORC storage (with likely
 * a 2-3 minute delay).
 * 
 * Live log data is sent by the application servers in the following fashion:
 * 
 * [nginx] --json--> [rsyslog] --tsv--> [flume] --tsv--> [hdfs]
 * 
 * Flume stores the TSV files in directories partitioned by minute. This background job then runs
 * periodically to migrate this per-minute TSV data into the permanent ORC storage. The data is
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
public class ConvertLiveDataToOrc implements Runnable {
  private static final String HDFS_URI =
      System.getProperty("apiumbrella.hdfs_uri", "hdfs://127.0.0.1:8020");
  private static final String HDFS_ROOT = "/apps/api-umbrella";
  private static final String HDFS_LOGS_ROOT = HDFS_ROOT + "/logs";
  private static final String HDFS_LOGS_LIVE_ROOT = HDFS_ROOT + "/logs-live";
  private static final String LOGS_TABLE_NAME = "api_umbrella.logs";
  private static final String LOGS_LIVE_TABLE_NAME = "api_umbrella.logs_live";
  private static final Path LAST_MIGRATED_MARKER =
      new Path(HDFS_URI + HDFS_ROOT + "/.logs-live-last-migrated-partition-time");
  final Logger logger;

  Pattern partitionDatePattern = Pattern.compile(
      ".*request_at_tz_date=(\\d{4}-\\d{2}-\\d{2})/request_at_tz_hour_minute=(\\d{2})-(\\d{2}).*");
  DateTimeFormatter dateFormatter = ISODateTimeFormat.date();
  DateTimeFormatter hourMinuteFormatter = DateTimeFormat.forPattern("HH-mm");
  private LogSchema logSchema;
  private String createExternalTableSql;
  private String createLiveExternalTableSql;
  private String addPartitionSql;
  private String addLivePartitionSql;
  private String insertSql;
  private long lastMigratedPartitionTime = 0;
  private boolean tablesCreated = false;
  private FileSystem fileSystem;

  public ConvertLiveDataToOrc(App app) {
    logSchema = new LogSchema();
    logger = app.logger;

    try {
      // Load the Hive JDBC class.
      Class.forName("org.apache.hive.jdbc.HiveDriver");

      Configuration conf = new Configuration();
      // Fix for hadoop jar ordering: http://stackoverflow.com/a/21118824
      conf.set("fs.hdfs.impl", org.apache.hadoop.hdfs.DistributedFileSystem.class.getName());
      conf.set("fs.file.impl", org.apache.hadoop.fs.LocalFileSystem.class.getName());

      fileSystem = FileSystem.get(new URI(HDFS_URI), conf);
      if (fileSystem.exists(LAST_MIGRATED_MARKER)) {
        FSDataInputStream markerInputStream = fileSystem.open(LAST_MIGRATED_MARKER);
        lastMigratedPartitionTime = Long.parseLong(IOUtils.toString(markerInputStream), 10);
        logger.debug("Read last migrated partition timestamp marker: " + lastMigratedPartitionTime);
      }
    } catch (Exception e) {
      e.printStackTrace();
      System.exit(1);
    }
  }

  public void run() {
    logger.debug("Begin processing");
    Connection connection = null;
    try {
      connection =
          DriverManager.getConnection("jdbc:hive2://localhost:10000/api_umbrella", "hive", "");
      createTables(connection);
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

          PreparedStatement migrate = connection.prepareStatement(getMigrateSql());
          migrate.setString(1, dateFormatter.print(partition.withDayOfYear(1)));
          migrate.setString(2, dateFormatter.print(partition.withDayOfMonth(1)));
          migrate.setString(3, dateFormatter.print(partition.withDayOfWeek(1)));
          migrate.setString(4, dateFormatter.print(partition));
          migrate.setString(5, dateFormatter.print(partition));
          migrate.setString(6, hourMinuteFormatter.print(partition));
          migrate.executeUpdate();
          migrate.close();

          lastMigratedPartitionTime = partition.getMillis();

          FSDataOutputStream markerOutputStream = fileSystem.create(LAST_MIGRATED_MARKER, true);
          BufferedWriter br = new BufferedWriter(new OutputStreamWriter(markerOutputStream));
          br.write(Long.toString(lastMigratedPartitionTime));
          br.close();
        } else {
          logger.debug("Skipping already processed partition: " + partition);
        }
      }
    } catch (Exception e) {
      e.printStackTrace();
    } finally {
      try {
        if (connection != null) {
          connection.close();
        }
      } catch (SQLException e) {
        e.printStackTrace();
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
  private void createTables(Connection connection) throws SQLException {
    if (tablesCreated == false) {
      Statement statement = connection.createStatement();
      statement.executeUpdate(getCreateExternalTableSql());
      statement.executeUpdate(getCreateLiveExternalTableSql());
      statement.close();
      tablesCreated = true;
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
  private String getCreateExternalTableSql() {
    if (createExternalTableSql == null) {
      StringBuilder sql = new StringBuilder();
      sql.append("CREATE EXTERNAL TABLE IF NOT EXISTS " + LOGS_TABLE_NAME + "(");
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

      sql.append("STORED AS ORC LOCATION '" + HDFS_LOGS_ROOT + "'");

      createExternalTableSql = sql.toString();
    }

    return createExternalTableSql;
  }

  /**
   * Generate the SQL string for creating the external "api_umbrella.logs_live" table in Hive. This
   * is the table that stores temporary data, partitioned by minute, that Flume is writing to HDFS
   * TSV files to.
   * 
   * The columns are generated based on the Avro schema definition (src/main/resources/log.avsc) for
   * our log data to ensure the schemas match across the different tables.
   * 
   * @return
   */
  private String getCreateLiveExternalTableSql() {
    if (createLiveExternalTableSql == null) {
      StringBuilder sql = new StringBuilder();
      sql.append("CREATE EXTERNAL TABLE IF NOT EXISTS " + LOGS_LIVE_TABLE_NAME + "(");
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

      sql.append("ROW FORMAT DELIMITED FIELDS TERMINATED BY '\\t' ");
      sql.append("STORED AS TEXTFILE LOCATION '" + HDFS_LOGS_LIVE_ROOT + "'");

      createLiveExternalTableSql = sql.toString();
    }

    return createLiveExternalTableSql;
  }

  /**
   * Generate the SQL string for adding new date partitions to the "api_umbrella.logs" table.
   * 
   * @return
   */
  private String getAddPartitionSql() {
    if (addPartitionSql == null) {
      StringBuilder sql = new StringBuilder();
      sql.append("ALTER TABLE " + LOGS_TABLE_NAME + " ADD IF NOT EXISTS ");
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
  private String getAddLivePartitionSql() {
    if (addLivePartitionSql == null) {
      StringBuilder sql = new StringBuilder();
      sql.append("ALTER TABLE " + LOGS_LIVE_TABLE_NAME + " ADD IF NOT EXISTS ");
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

  /**
   * Generate the SQL string that copies a minute worth of data from the "api_umbrella.logs_live"
   * table (TSV storage) to the real "api_umbrella.logs" table (ORC storage).
   * 
   * Data is appended to the ORC table's full-day partition, so it's expected that this will run
   * repeatedly for each new minute of data, but the same minute should not be repeated (or else the
   * same data will be appended twice to the ORC table).
   * 
   * @return
   */
  private String getMigrateSql() {
    if (insertSql == null) {
      StringBuilder sql = new StringBuilder();
      sql.append("INSERT INTO TABLE " + LOGS_TABLE_NAME + " ");

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

      sql.append(" FROM " + LOGS_LIVE_TABLE_NAME + " WHERE ");
      for (int i = 0; i < logSchema.getLivePartitionFieldsList().size(); i++) {
        if (i > 0) {
          sql.append(" AND ");
        }
        sql.append(logSchema.getLivePartitionFieldsList().get(i) + "=?");
      }
      sql.append(" ORDER BY request_at");

      insertSql = sql.toString();
    }

    return insertSql;
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
        fileSystem.listFiles(new Path(HDFS_URI + HDFS_LOGS_LIVE_ROOT), true);

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
        logger.error("Partition with active files is unexpectedly older than the most recently "
            + "processed data. This means older data is being populated in the live data files. "
            + "This data will not automatically be processed. Manual cleanup is required. "
            + "Partition: " + activePartition);
      }
    }

    return inactivePartitions;
  }
}
