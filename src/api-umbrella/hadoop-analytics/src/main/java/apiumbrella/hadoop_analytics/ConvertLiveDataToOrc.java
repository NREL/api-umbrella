package apiumbrella.hadoop_analytics;

import java.nio.file.Paths;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Map;
import java.util.TreeMap;
import java.util.TreeSet;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.FileStatus;
import org.apache.hadoop.fs.FileSystem;
import org.apache.hadoop.fs.LocatedFileStatus;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.fs.RemoteIterator;
import org.joda.time.DateTime;
import org.joda.time.format.DateTimeFormat;
import org.joda.time.format.DateTimeFormatter;
import org.joda.time.format.ISODateTimeFormat;

public class ConvertLiveDataToOrc implements Runnable {
  protected static String HDFS_URI =
      System.getProperty("apiumbrella.hdfs_uri", "hdfs://127.0.0.1:8020");

  Pattern partitionDatePattern = Pattern.compile(
      ".*request_at_tz_date=(\\d{4}-\\d{2}-\\d{2})/request_at_tz_hour_minute=(\\d{2})-(\\d{2}).*");
  DateTimeFormatter dateFormatter = ISODateTimeFormat.date();
  DateTimeFormatter hourMinuteFormatter = DateTimeFormat.forPattern("HH-mm");
  Connection connection;

  public ConvertLiveDataToOrc() {
    try {
      connection = DriverManager.getConnection("jdbc:hive2://localhost:10000/api_umbrella", "hive", "");
      createTable();
    } catch (SQLException e) {
      e.printStackTrace();
    }
  }

  public void run() {
    try {
      Configuration conf = new Configuration();
      conf.addResource(new Path("/usr/hdp/current/hadoop-client/conf/core-site.xml"));
      FileSystem fs = FileSystem.get(conf);
      RemoteIterator<LocatedFileStatus> filesIter =
          fs.listFiles(new Path(HDFS_URI + "/tmp/flume-test/take4"), true);

      TreeMap<Path, TreeSet<FileStatus>> partitionFiles = new TreeMap<Path, TreeSet<FileStatus>>();
      TreeSet<Path> staticPartitions = new TreeSet<Path>();
      TreeSet<Path> activePartitions = new TreeSet<Path>();
      long staticTimeThreshold = new DateTime().minusMinutes(1).getMillis();
      while (filesIter.hasNext()) {
        FileStatus file = filesIter.next();
        Path partition = file.getPath().getParent();
        TreeSet<FileStatus> files = partitionFiles.get(partition);
        if (files == null) {
          files = new TreeSet<FileStatus>();
        }

        files.add(file);
        partitionFiles.put(partition, files);

        // If the file was recently written to, mark the partition as active (since we don't want to
        // tough it until we're sure no more data will show up in it).
        if (file.getModificationTime() > staticTimeThreshold) {
          activePartitions.add(partition);
        } else {
          // If the file is older, but currently being written to (denoted by Flume prefixing the
          // file with an "_" so it's ignored from Hive), then we also want to ignore it. However,
          // this case should be rare, since it would indicate Flume is writing to an older file
          // than we expect.
          if (file.getPath().getName().startsWith("_")) {
            activePartitions.add(partition);
          } else {
            staticPartitions.add(partition);
          }
        }
      }

      // Loop through all the active partitions and ensure that none of these are also marked as
      // static. This handles situations where the partition might have some older files, but other
      // files still being written to.
      for (Path partition : activePartitions) {
        staticPartitions.remove(partition);
        System.out.println("ACTIVE PARTITIONS: " + partition);
      }

      for (Path partition : staticPartitions) {
        System.out.println(partition.toString());
        Matcher matcher = partitionDatePattern.matcher(partition.toString());
        DateTime partitionTime = null;
        while (matcher.find()) {
          partitionTime = new DateTime(
              matcher.group(1) + "T" + matcher.group(2) + ":" + matcher.group(3) + ":00");
        }
        System.out.println("STATIC PARTITIONS: " + partition);
        String addPartitionSql = String.format(
            "ALTER TABLE " //
                + "api_umbrella.logs_archive " //
                + "ADD IF NOT EXISTS " //
                + "PARTITION(" //
                + "request_at_tz_year=%d," //
                + "request_at_tz_month=%d," //
                + "request_at_tz_week=%d," //
                + "request_at_tz_date='%s')",
            partitionTime.getYear(), partitionTime.getMonthOfYear(),
            partitionTime.getWeekOfWeekyear(), this.dateFormatter.print(partitionTime));

        String insertSql = String.format(
            "INSERT INTO TABLE api_umbrella.logs_archive " //
                + "PARTITION(" //
                + "request_at_tz_year=%d," //
                + "request_at_tz_month=%d," //
                + "request_at_tz_week=%d," //
                + "request_at_tz_date='%s') " //
                + "SELECT " //
                + "request_at," //
                + "id," //
                + "request_at_tz_offset," //
                + "request_at_tz_year," //
                + "request_at_tz_month," //
                + "request_at_tz_week," //
                + "request_at_tz_hour," //
                + "request_at_tz_minute," //
                + "user_id," //
                + "denied_reason," //
                + "request_method," //
                + "request_url_scheme," //
                + "request_url_host," //
                + "request_url_port," //
                + "request_url_path," //
                + "request_url_path_level1," //
                + "request_url_path_level2," //
                + "request_url_path_level3," //
                + "request_url_path_level4," //
                + "request_url_path_level5," //
                + "request_url_path_level6," //
                + "request_url_query," //
                + "request_ip," //
                + "request_ip_country," //
                + "request_ip_region," //
                + "request_ip_city," //
                + "request_ip_lat," //
                + "request_ip_lon," //
                + "request_user_agent," //
                + "request_user_agent_type," //
                + "request_user_agent_family," //
                + "request_size," //
                + "request_accept," //
                + "request_accept_encoding," //
                + "request_content_type," //
                + "request_connection," //
                + "request_origin," //
                + "request_referer," //
                + "request_basic_auth_username," //
                + "response_status," //
                + "response_content_type," //
                + "response_content_length," //
                + "response_content_encoding," //
                + "response_transfer_encoding," //
                + "response_server," //
                + "response_cache," //
                + "response_age," //
                + "response_size," //
                + "timer_response," //
                + "timer_backend_response," //
                + "timer_internal," //
                + "timer_proxy_overhead," //
                + "log_imported " //
                + "FROM api_umbrella.logs_live " //
                + "WHERE " //
                + "request_at_tz_date='%s' " //
                + "AND request_at_tz_hour_minute='%s' " //
                + "ORDER BY request_at",
            partitionTime.getYear(), partitionTime.getMonthOfYear(),
            partitionTime.getWeekOfWeekyear(), this.dateFormatter.print(partitionTime),
            this.dateFormatter.print(partitionTime), this.hourMinuteFormatter.print(partitionTime));
        System.out.println(insertSql);
      }
    } catch (Exception e) {
      e.printStackTrace();
    }
    /*
     * Statement stmt = con.createStatement();
     * 
     * FsShell shell = new FsShell(); String[] args = { "-ls", "-R", "/tmp/flume-test/take4" };
     * ToolRunner.run(shell, args);
     * 
     * "ALTER TABLE api_umbrella.logs_archive ADD IF NOT EXISTS PARTITION(request_at_tz_year=2016, request_at_tz_month=3, request_at_tz_week=11, request_at_tz_date='2016-03-16');"
     * "INSERT INTO TABLE api_umbrella.logs_archive PARTITION(request_at_tz_year=2016, request_at_tz_month=3, request_at_tz_week=11, request_at_tz_date='2016-03-16') SELECT request_at, id, request_at_tz_offset, request_at_tz_hour, request_at_tz_minute, user_id, denied_reason, request_method, request_url_scheme, request_url_host, request_url_port, request_url_path, request_url_path_level1, request_url_path_level2, request_url_path_level3, request_url_path_level4, request_url_path_level5, request_url_path_level6, request_url_query, request_ip, request_ip_country, request_ip_region, request_ip_city, request_ip_lat, request_ip_lon, request_user_agent, request_user_agent_type, request_user_agent_family, request_size, request_accept, request_accept_encoding, request_content_type, request_connection, request_origin, request_referer, request_basic_auth_username, response_status, response_content_type, response_content_length, response_content_encoding, response_transfer_encoding, response_server, response_cache, response_age, response_size, timer_response, timer_backend_response, timer_internal, timer_proxy_overhead, log_imported FROM api_umbrella.logs_live WHERE request_at_tz_year=2016 AND request_at_tz_month=3 AND request_at_tz_date='2016-03-16' ORDER BY request_at;"
     * "INSERT OVERWRITE TABLE api_umbrella.logs_live_orc PARTITION(request_at_tz_date='2016-03-16', request_at_tz_hour=1, request_at_tz_minute=41) SELECT request_at, id, request_at_tz_offset, request_at_tz_year, request_at_tz_month, request_at_tz_week, user_id, denied_reason, request_method, request_url_scheme, request_url_host, request_url_port, request_url_path, request_url_path_level1, request_url_path_level2, request_url_path_level3, request_url_path_level4, request_url_path_level5, request_url_path_level6, request_url_query, request_ip, request_ip_country, request_ip_region, request_ip_city, request_ip_lat, request_ip_lon, request_user_agent, request_user_agent_type, request_user_agent_family, request_size, request_accept, request_accept_encoding, request_content_type, request_connection, request_origin, request_referer, request_basic_auth_username, response_status, response_content_type, response_content_length, response_content_encoding, response_transfer_encoding, response_server, response_cache, response_age, response_size, timer_response, timer_backend_response, timer_internal, timer_proxy_overhead, log_imported FROM api_umbrella.logs_live WHERE request_at_tz_date='2016-03-16' AND request_at_tz_hour=1 AND request_at_tz_minute=41 ORDER BY request_at;"
     */
  }

  private void createTable() throws SQLException {
    String createSql = "CREATE EXTERNAL TABLE IF NOT EXISTS api_umbrella.logs_live(" //
        + "request_at BIGINT," //
        + "id STRING," //
        + "request_at_tz_offset INT," //
        + "request_at_tz_year SMALLINT," //
        + "request_at_tz_month SMALLINT," //
        + "request_at_tz_week SMALLINT," //
        + "request_at_tz_hour SMALLINT," //
        + "request_at_tz_minute SMALLINT," //
        + "user_id STRING," //
        + "denied_reason STRING," //
        + "request_method STRING," //
        + "request_url_scheme STRING," //
        + "request_url_host STRING," //
        + "request_url_port INT," //
        + "request_url_path STRING," //
        + "request_url_path_level1 STRING," //
        + "request_url_path_level2 STRING," //
        + "request_url_path_level3 STRING," //
        + "request_url_path_level4 STRING," //
        + "request_url_path_level5 STRING," //
        + "request_url_path_level6 STRING," //
        + "request_url_query STRING," //
        + "request_ip STRING," //
        + "request_ip_country STRING," //
        + "request_ip_region STRING," //
        + "request_ip_city STRING," //
        + "request_ip_lat DOUBLE," //
        + "request_ip_lon DOUBLE," //
        + "request_user_agent STRING," //
        + "request_user_agent_type STRING," //
        + "request_user_agent_family STRING," //
        + "request_size INT," //
        + "request_accept STRING," //
        + "request_accept_encoding STRING," //
        + "request_content_type STRING," //
        + "request_connection STRING," //
        + "request_origin STRING," //
        + "request_referer STRING," //
        + "request_basic_auth_username STRING," //
        + "response_status SMALLINT," //
        + "response_content_type STRING," //
        + "response_content_length INT," //
        + "response_content_encoding STRING," //
        + "response_transfer_encoding STRING," //
        + "response_server STRING," //
        + "response_cache STRING," //
        + "response_age INT," //
        + "response_size INT," //
        + "timer_response DOUBLE," //
        + "timer_backend_response DOUBLE," //
        + "timer_internal DOUBLE," //
        + "timer_proxy_overhead DOUBLE," //
        + "log_imported BOOLEAN) " //
        + "PARTITIONED BY (request_at_tz_date DATE, request_at_tz_hour_minute STRING) " //
        + "ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' " //
        + "STORED AS TEXTFILE LOCATION '/tmp/flume-test/take4'";
    Statement statement = connection.createStatement();
    statement.executeQuery(createSql);

    String createArchiveSql = "CREATE EXTERNAL TABLE IF NOT EXISTS api_umbrella.logs_archive(" //
        + "request_at BIGINT," //
        + "id STRING," //
        + "request_at_tz_offset INT," //
        + "request_at_tz_year SMALLINT," //
        + "request_at_tz_month SMALLINT," //
        + "request_at_tz_week SMALLINT," //
        + "request_at_tz_hour SMALLINT," //
        + "request_at_tz_minute SMALLINT," //
        + "user_id STRING," //
        + "denied_reason STRING," //
        + "request_method STRING," //
        + "request_url_scheme STRING," //
        + "request_url_host STRING," //
        + "request_url_port INT," //
        + "request_url_path STRING," //
        + "request_url_path_level1 STRING," //
        + "request_url_path_level2 STRING," //
        + "request_url_path_level3 STRING," //
        + "request_url_path_level4 STRING," //
        + "request_url_path_level5 STRING," //
        + "request_url_path_level6 STRING," //
        + "request_url_query STRING," //
        + "request_ip STRING," //
        + "request_ip_country STRING," //
        + "request_ip_region STRING," //
        + "request_ip_city STRING," //
        + "request_ip_lat DOUBLE," //
        + "request_ip_lon DOUBLE," //
        + "request_user_agent STRING," //
        + "request_user_agent_type STRING," //
        + "request_user_agent_family STRING," //
        + "request_size INT," //
        + "request_accept STRING," //
        + "request_accept_encoding STRING," //
        + "request_content_type STRING," //
        + "request_connection STRING," //
        + "request_origin STRING," //
        + "request_referer STRING," //
        + "request_basic_auth_username STRING," //
        + "response_status SMALLINT," //
        + "response_content_type STRING," //
        + "response_content_length INT," //
        + "response_content_encoding STRING," //
        + "response_transfer_encoding STRING," //
        + "response_server STRING," //
        + "response_cache STRING," //
        + "response_age INT," //
        + "response_size INT," //
        + "timer_response DOUBLE," //
        + "timer_backend_response DOUBLE," //
        + "timer_internal DOUBLE," //
        + "timer_proxy_overhead DOUBLE," //
        + "log_imported BOOLEAN) " //
        + "PARTITIONED BY (" //
        + "request_at_tz_year SMALLINT," //
        + "request_at_tz_month TINYINT," //
        + "request_at_tz_week TINYINT," //
        + "request_at_tz_date DATE) " //
        + "STORED AS ORC LOCATION '/tmp/flume-test/take4-orc'";
    Statement archiveStatement = connection.createStatement();
    archiveStatement.executeQuery(createArchiveSql);
  }
}
