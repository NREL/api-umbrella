package apiumbrella.hadoop_analytics;

import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.URISyntaxException;
import java.net.URL;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.TreeSet;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.apache.commons.httpclient.HttpClient;
import org.apache.commons.httpclient.HttpException;
import org.apache.commons.httpclient.HttpMethod;
import org.apache.commons.httpclient.UsernamePasswordCredentials;
import org.apache.commons.httpclient.auth.AuthScope;
import org.apache.commons.httpclient.methods.GetMethod;
import org.apache.commons.httpclient.methods.PutMethod;
import org.apache.commons.httpclient.methods.RequestEntity;
import org.apache.commons.httpclient.methods.StringRequestEntity;
import org.apache.commons.io.IOUtils;
import org.apache.hadoop.fs.FileStatus;
import org.apache.hadoop.fs.LocatedFileStatus;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.fs.RemoteIterator;
import org.joda.time.DateTime;
import org.joda.time.DateTimeZone;
import org.joda.time.Days;
import org.joda.time.format.DateTimeFormat;
import org.joda.time.format.DateTimeFormatter;
import org.joda.time.format.ISODateTimeFormat;
import org.quartz.DisallowConcurrentExecution;
import org.quartz.Job;
import org.quartz.JobExecutionContext;
import org.quartz.JobExecutionException;
import org.quartz.PersistJobDataAfterExecution;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.google.gson.JsonSyntaxException;

@DisallowConcurrentExecution
@PersistJobDataAfterExecution
public class RefreshKylin implements Job {
  final Logger logger;
  private static final String KYLIN_URL =
      System.getProperty("apiumbrella.kylin_url", "http://127.0.0.1:7070/kylin");
  private static final String KYLIN_USERNAME =
      System.getProperty("apiumbrella.kylin_username", "ADMIN");
  private static final String KYLIN_PASSWORD =
      System.getProperty("apiumbrella.kylin_password", "KYLIN");
  private static final String KYLIN_REFRESH_END_DATE =
      System.getProperty("apiumbrella.kylin_refresh_end_date");
  private static final String CUBE_NAME = "logs_cube";
  DateTimeFormatter dateFormatter = ISODateTimeFormat.date();
  DateTimeFormatter hourMinuteFormatter = DateTimeFormat.forPattern("HH-mm");
  DateTimeFormatter dateTimeFormatter =
      DateTimeFormat.forPattern("yyyy-MM-dd HH:mm:ss").withZone(App.TIMEZONE);
  private HttpClient client;
  private Connection connection;

  public RefreshKylin() {
    logger = LoggerFactory.getLogger(this.getClass());
    logger.debug("Initializing " + this.getClass());
  }

  public void execute(JobExecutionContext context) throws JobExecutionException {
    try {
      connection = null;
      try {
        connection = App.getHiveConnection();
        run();
      } finally {
        if (connection != null) {
          connection.close();
        }
      }
    } catch (Exception e) {
      logger.error("Refresh kylin error", e);
      try {
        Thread.sleep(30000);
      } catch (InterruptedException e1) {
        e1.printStackTrace();
      }
      JobExecutionException jobError = new JobExecutionException(e);
      jobError.refireImmediately();
      throw jobError;
    }
  }

  public void run() throws JsonSyntaxException, HttpException, IOException, SQLException,
      ClassNotFoundException, IllegalArgumentException, URISyntaxException, InterruptedException {
    logger.info("Begin kylin refresh");

    URL url = new URL(KYLIN_URL);
    client = new HttpClient();
    UsernamePasswordCredentials credentials =
        new UsernamePasswordCredentials(KYLIN_USERNAME, KYLIN_PASSWORD);
    AuthScope authScope = new AuthScope(url.getHost(), url.getPort(), AuthScope.ANY_REALM);
    client.getState().setCredentials(authScope, credentials);
    client.getParams().setAuthenticationPreemptive(true);

    /* Determine the last table partition with data in it. */
    DateTime lastPartitionDayStart = getPartitions(App.LOGS_TABLE_NAME).last();
    if (lastPartitionDayStart == null) {
      logger.info("No data partitions exist, skipping kylin refresh");
      return;
    }

    /*
     * Determine how far Kylin should process data until. It should process until the most recent
     * partition with data, but never process today's current data (we will defer processing each
     * day until the day is over, so we don't have to worry about refreshing data).
     */
    DateTime processUntilDayStart;
    DateTime currentDayStart =
        new DateTime(App.TIMEZONE).withTimeAtStartOfDay().withZoneRetainFields(DateTimeZone.UTC);
    if (lastPartitionDayStart.isAfter(currentDayStart)
        || lastPartitionDayStart.isEqual(currentDayStart)) {
      processUntilDayStart = lastPartitionDayStart.minusDays(1);
    } else {
      processUntilDayStart = lastPartitionDayStart;
    }
    if (KYLIN_REFRESH_END_DATE != null) {
      DateTimeFormatter dateParser = ISODateTimeFormat.dateParser().withZone(App.TIMEZONE);
      processUntilDayStart = dateParser.parseDateTime(KYLIN_REFRESH_END_DATE);
    }
    logger.debug("Process until: " + processUntilDayStart + " (last partition: "
        + lastPartitionDayStart + ")");
    DateTime processUntilDayEnd = processUntilDayStart.plusDays(1);
    DateTime segmentStart = null;
    DateTime segmentEnd = null;

    /*
     * Before processing the last day of data, perform some additional data migrations to better
     * optimize any of the daily partitions that were originally populated from the streaming live
     * data.
     */
    TreeSet<DateTime> livePartitions = getPartitions(App.LOGS_LIVE_TABLE_NAME);
    for (DateTime livePartition : livePartitions) {
      if (livePartition.isBefore(processUntilDayStart) || livePartition == processUntilDayStart) {
        /*
         * First, ensure the day's partition is done writing to (this should generally be the case,
         * since this refresh kylin task is only called after midnight).
         */
        waitForNoWriteActivityOnDayPartition(livePartition);

        /*
         * Next, re-write the daily ORC partition with the live data. This better optimizes the data
         * for long-term storage (less stripes than the data originally written from streaming
         * appends). This also helps mitigate any potential edge-cases that may have led to the live
         * data being missed during the live append process.
         */
        overwriteDayPartitionFromLiveData(livePartition);

        /*
         * Finally, remove the live data for this day, since the ORC data is now the definitive
         * copy.
         */
        removeLiveDataForDay(livePartition);
      }
    }

    /* Loop through the existing segments and see if any of them need to be refreshed. */
    JsonArray segments = getSegments();
    for (JsonElement segment : segments) {
      JsonObject segmentObject = segment.getAsJsonObject();

      /* Kill this run and wait for the next one if any segments are still processing. */
      String segmentName = segmentObject.get("name").getAsString();
      String segmentStatus = segmentObject.get("status").getAsString();
      if (!segmentStatus.equals("READY")) {
        logger.info("Segment still processing, waiting for next refresh: " + segmentName + " - "
            + segmentStatus);
        return;
      }

      segmentStart =
          new DateTime(segmentObject.get("date_range_start").getAsLong(), DateTimeZone.UTC);
      segmentEnd = new DateTime(segmentObject.get("date_range_end").getAsLong(), DateTimeZone.UTC);
      DateTime segmentBuild =
          new DateTime(segmentObject.get("last_build_time").getAsLong(), DateTimeZone.UTC);

      /*
       * If the segment was built before the segment day is finished, then it needs to be refreshed.
       * We'll also continue refreshing for up to 50 minutes after the day is finished to account
       * for delayed data getting populated.
       */
      if (segmentBuild.isBefore(segmentEnd.plusMinutes(50))) {
        buildSegment("REFRESH", segmentStart, segmentEnd);
      }
    }

    /*
     * Define the next segment to build: Either the day following the last existing segment, or the
     * beginning of the cube if no existing segments exist.
     */
    if (segmentStart == null) {
      segmentStart = getCubeStart();
    } else {
      segmentStart = new DateTime(segmentEnd);
    }

    /* Loop over any segments that need building until the last partition day is hit. */
    while (segmentStart.isBefore(processUntilDayEnd)) {
      /*
       * Build a segment from the first day needed until the last partition day. But handle segments
       * longer than 1 full day a bit differently.
       */
      segmentEnd = new DateTime(processUntilDayEnd);
      if (Days.daysBetween(segmentStart, segmentEnd).getDays() > 1) {
        if (segmentStart.getYear() != segmentEnd.getYear()) {
          /*
           * If this segment would span separate years, then create separate segments for each
           * calendar year. When first importing historical data, this helps the segment out the
           * first big bulk processing.
           */
          segmentEnd = segmentStart.withDayOfYear(1).plusYears(1);
        } else {
          /*
           * Otherwise, if the segment would span multiple days, first create a segment until the
           * second to last day. Then we'll create a separate segment for the final day. This helps
           * ensure that the last day (which may contain live data), is put in its own segment, so
           * it's quicker to re-process once the day is complete.
           */
          segmentEnd = segmentEnd.minusDays(1);
        }
      }

      buildSegment("BUILD", segmentStart, segmentEnd);
      segmentStart = segmentEnd;
    }

    logger.info("Finish kylin refresh");
  }

  private JsonArray getSegments() throws HttpException, JsonSyntaxException, IOException {
    GetMethod method = new GetMethod(KYLIN_URL + "/api/cubes/" + CUBE_NAME);
    JsonObject result = makeRequest(method).getAsJsonObject();
    JsonArray segments = result.get("segments").getAsJsonArray();

    return segments;
  }

  private DateTime getCubeStart() throws HttpException, JsonSyntaxException, IOException {
    GetMethod method = new GetMethod(KYLIN_URL + "/api/cube_desc/" + CUBE_NAME);
    JsonObject result = makeRequest(method).getAsJsonArray().get(0).getAsJsonObject();
    DateTime start = new DateTime(result.get("partition_date_start").getAsLong(), DateTimeZone.UTC);

    return start;
  }

  private TreeSet<DateTime> getPartitions(String tableName)
      throws FileNotFoundException, IllegalArgumentException, IOException, URISyntaxException,
      ClassNotFoundException, SQLException {
    TreeSet<DateTime> partitions = new TreeSet<DateTime>();
    Pattern partitionDatePattern = Pattern.compile("timestamp_tz_date=(\\d{4}-\\d{2}-\\d{2})");
    PreparedStatement statement = connection.prepareStatement("SHOW PARTITIONS " + tableName);
    ResultSet rs = statement.executeQuery();
    while (rs.next()) {
      logger.debug(tableName + " partition: " + rs.getString("partition"));
      Matcher matcher = partitionDatePattern.matcher(rs.getString("partition").toString());
      DateTime partitionTime = null;
      while (matcher.find()) {
        partitionTime = new DateTime(matcher.group(1) + "T00:00:00");
      }

      partitions.add(partitionTime);
    }

    return partitions;
  }

  private void waitForNoWriteActivityOnDayPartition(DateTime partition)
      throws FileNotFoundException, IllegalArgumentException, IOException, URISyntaxException,
      InterruptedException {
    long inactiveTimeThreshold = new DateTime().minusMinutes(30).getMillis();
    long lastModifiedFile = 0;
    do {
      RemoteIterator<LocatedFileStatus> filesIter = App.getHadoopFileSystem()
          .listFiles(new Path(App.HDFS_URI + App.HDFS_LOGS_ROOT //
              + "/timestamp_tz_year=" + dateFormatter.print(partition.withDayOfYear(1))
              + "/timestamp_tz_month=" + dateFormatter.print(partition.withDayOfMonth(1))
              + "/timestamp_tz_week=" + dateFormatter.print(partition.withDayOfWeek(1))
              + "/timestamp_tz_date=" + dateFormatter.print(partition)), true);
      while (filesIter.hasNext()) {
        FileStatus file = filesIter.next();
        logger.debug(file.getPath() + " file last modified: " + file.getModificationTime());
        if (file.getModificationTime() > lastModifiedFile) {
          lastModifiedFile = file.getModificationTime();
        }
      }

      if (lastModifiedFile > inactiveTimeThreshold) {
        logger.info("Previous day partition has recently written data. "
            + "Waiting until write activity hasn't occurred in 30 minutes. Last modification: "
            + lastModifiedFile);
        Thread.sleep(60000);
      }
    } while (lastModifiedFile == 0 || lastModifiedFile > inactiveTimeThreshold);
  }

  private void overwriteDayPartitionFromLiveData(DateTime partition)
      throws ClassNotFoundException, SQLException {
    logger.info("Begin overwrite of partition " + partition + " from " + App.LOGS_LIVE_TABLE_NAME);

    PreparedStatement statement = connection.prepareStatement(
        "SELECT COUNT(*) AS count FROM " + App.LOGS_TABLE_NAME + " WHERE timestamp_tz_date=?");
    statement.setString(1, dateFormatter.print(partition));
    ResultSet rs = statement.executeQuery();
    long beforePartitionCount = 0;
    if (rs.next()) {
      beforePartitionCount = rs.getLong("count");
      logger.debug("Partition (" + partition + ") count before overwrite: ", beforePartitionCount);
    }

    PreparedStatement migrate =
        connection.prepareStatement(ConvertLiveDataToOrc.getInsertOverwriteDaySql());
    migrate.setString(1, dateFormatter.print(partition.withDayOfYear(1)));
    migrate.setString(2, dateFormatter.print(partition.withDayOfMonth(1)));
    migrate.setString(3, dateFormatter.print(partition.withDayOfWeek(1)));
    migrate.setString(4, dateFormatter.print(partition));
    migrate.setString(5, dateFormatter.print(partition));
    migrate.executeUpdate();
    migrate.close();

    rs = statement.executeQuery();
    long afterPartitionCount = 0;
    if (rs.next()) {
      afterPartitionCount = rs.getLong("count");
      logger.debug("Partition (" + partition + ") count after overwrite: ", beforePartitionCount);
    }

    if (beforePartitionCount != afterPartitionCount) {
      logger.warn("Partition (" + partition + ") counts did not match");
    }

    logger.info("Finish overwrite of partition " + partition + " from " + App.LOGS_LIVE_TABLE_NAME);
  }

  private void removeLiveDataForDay(DateTime partition)
      throws SQLException, IllegalArgumentException, IOException, URISyntaxException {
    logger.info("Removing ");
    PreparedStatement addLivePartition =
        connection.prepareStatement(ConvertLiveDataToOrc.getDropLivePartitionsDaySql());
    addLivePartition.setString(1, dateFormatter.print(partition));
    addLivePartition.setString(2, hourMinuteFormatter.print(partition));
    addLivePartition.executeUpdate();
    addLivePartition.close();

    App.getHadoopFileSystem()
        .delete(new Path(App.HDFS_URI + App.HDFS_LOGS_LIVE_ROOT //
            + "/timestamp_tz_date=" + dateFormatter.print(partition) //
            + "/timestamp_tz_hour_minute=" + hourMinuteFormatter.print(partition)), true);
  }

  private void buildSegment(String buildType, DateTime start, DateTime end)
      throws HttpException, JsonSyntaxException, IOException, ClassNotFoundException,
      IllegalArgumentException, SQLException, URISyntaxException {
    /*
     * Before building any segments with Kylin, ensure that the table partitions are optimized by
     * merging multiple files into 1.
     */
    App.concatenateTablePartitions(logger);

    logger.info("Begin building segment (" + buildType + "): " + start + " - " + end);

    PutMethod method = new PutMethod(KYLIN_URL + "/api/cubes/" + CUBE_NAME + "/rebuild");

    JsonObject data = new JsonObject();
    data.addProperty("buildType", buildType);
    data.addProperty("startTime", start.getMillis());
    data.addProperty("endTime", end.getMillis());

    RequestEntity entity = new StringRequestEntity(data.toString(), "application/json", "UTF-8");
    method.setRequestEntity(entity);

    JsonObject result = makeRequest(method).getAsJsonObject();
    String jobUuid = result.get("uuid").getAsString();
    waitForJob(jobUuid);

    logger.info("Finish building segment (" + buildType + "): " + start + " - " + end);
  }

  private String getJobStatus(String jobUuid)
      throws HttpException, JsonSyntaxException, IOException {
    GetMethod method = new GetMethod(KYLIN_URL + "/api/jobs/" + jobUuid);
    JsonObject result = makeRequest(method).getAsJsonObject();
    String status = result.get("job_status").getAsString();

    logger.debug("Job status: " + jobUuid + ": " + status);

    return status;
  }

  private void waitForJob(String jobUuid) throws HttpException, JsonSyntaxException, IOException {
    try {
      while (!getJobStatus(jobUuid).equals("FINISHED")) {
        Thread.sleep(30000);
      }
    } catch (InterruptedException ex) {
      Thread.currentThread().interrupt();
    }
  }

  private JsonElement makeRequest(HttpMethod method)
      throws HttpException, JsonSyntaxException, IOException {
    JsonElement result = null;
    try {
      client.executeMethod(method);
      int responseStatus = method.getStatusLine().getStatusCode();
      InputStreamReader responseBody = new InputStreamReader(method.getResponseBodyAsStream());
      if (responseStatus != 200) {
        logger.error("Failed to make request: " + method.getURI() + " - " + responseStatus + " - "
            + IOUtils.toString(responseBody));
        throw new HttpException("Unsuccessful HTTP response");
      }
      result = new JsonParser().parse(responseBody);
    } catch (HttpException e) {
      throw e;
    } catch (JsonSyntaxException e) {
      throw e;
    } catch (IOException e) {
      throw e;
    } finally {
      method.releaseConnection();
    }

    return result;
  }
}
