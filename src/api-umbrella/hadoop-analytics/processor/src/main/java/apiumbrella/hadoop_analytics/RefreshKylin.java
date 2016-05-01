package apiumbrella.hadoop_analytics;

import java.io.IOException;

import org.apache.commons.httpclient.HttpClient;
import org.apache.commons.httpclient.HttpException;
import org.apache.commons.httpclient.UsernamePasswordCredentials;
import org.apache.commons.httpclient.auth.AuthScope;
import org.apache.commons.httpclient.methods.GetMethod;
import org.apache.commons.httpclient.methods.PutMethod;
import org.apache.commons.httpclient.methods.RequestEntity;
import org.apache.commons.httpclient.methods.StringRequestEntity;
import org.joda.time.DateTime;
import org.joda.time.DateTimeZone;
import org.joda.time.format.DateTimeFormat;
import org.joda.time.format.DateTimeFormatter;
import org.slf4j.Logger;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.google.gson.JsonSyntaxException;

public class RefreshKylin implements Runnable {
  final Logger logger;
  private static final String KYLIN_URL =
      System.getProperty("apiumbrella.kylin_url", "http://127.0.0.1:7070/kylin");
  private static final String KYLIN_USERNAME =
      System.getProperty("apiumbrella.kylin_username", "ADMIN");
  private static final String KYLIN_PASSWORD =
      System.getProperty("apiumbrella.kylin_password", "KYLIN");
  private static final String CUBE_NAME = "logs_cube";
  DateTimeFormatter dateTimeFormatter =
      DateTimeFormat.forPattern("yyyy-MM-dd HH:mm:ss").withZone(App.TIMEZONE);
  private HttpClient client;

  public RefreshKylin(App app) {
    logger = app.logger;

    client = new HttpClient();
    UsernamePasswordCredentials credentials =
        new UsernamePasswordCredentials(KYLIN_USERNAME, KYLIN_PASSWORD);
    client.getState().setCredentials(AuthScope.ANY, credentials);
  }

  public void run() {
    try {
      logger.info("Begin kylin refresh");

      DateTime currentSegmentStart =
          new DateTime(App.TIMEZONE).withTimeAtStartOfDay().withZoneRetainFields(DateTimeZone.UTC);
      DateTime segmentStart = null;
      DateTime segmentEnd = null;

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
        segmentEnd =
            new DateTime(segmentObject.get("date_range_end").getAsLong(), DateTimeZone.UTC);
        DateTime segmentBuild =
            new DateTime(segmentObject.get("last_build_time").getAsLong(), DateTimeZone.UTC);

        /*
         * If the segment was built before the segment day is finsiehd, then it needs to be
         * refreshed. We'll also continue refreshing for up to 120 minutes after the day is finished
         * to account for delayed data getting populated.
         */
        if (segmentBuild.isBefore(segmentEnd.plusMinutes(120))) {
          buildSegment("REFRESH", segmentStart, segmentEnd);
        }
      }

      /*
       * Define the next segment to build: Either the day following the last existing segment, or
       * the current day if no existing segments exist.
       */
      if (segmentStart == null) {
        segmentStart = new DateTime(currentSegmentStart);
      } else {
        segmentStart = new DateTime(segmentEnd);
      }

      /* Loop over any segments that need building until the current day is hit. */
      while (segmentStart.isBefore(currentSegmentStart)
          || segmentStart.isEqual(currentSegmentStart)) {
        segmentEnd = segmentStart.plusDays(1);
        buildSegment("BUILD", segmentStart, segmentEnd);
        segmentStart = segmentEnd;
      }
    } catch (Exception e) {
      logger.error("kylin refresh error", e);
    }
    logger.info("Finish kylin refresh");
  }

  private JsonArray getSegments() {
    GetMethod method = new GetMethod(KYLIN_URL + "/api/cubes/" + CUBE_NAME);

    JsonArray segments = null;
    try {
      client.executeMethod(method);
      JsonObject result =
          new JsonParser().parse(method.getResponseBodyAsString()).getAsJsonObject();
      segments = result.get("segments").getAsJsonArray();
    } catch (HttpException e) {
      logger.error("getSegments error", e);
    } catch (JsonSyntaxException e) {
      logger.error("getSegments error", e);
    } catch (IOException e) {
      logger.error("getSegments error", e);
    }

    logger.debug("getSegments 5");

    return segments;
  }

  private void buildSegment(String buildType, DateTime start, DateTime end) {
    logger.info("Begin building segment (" + buildType + "): " + start + " - " + end);

    PutMethod method = new PutMethod(KYLIN_URL + "/api/cubes/" + CUBE_NAME + "/rebuild");

    try {
      JsonObject data = new JsonObject();
      data.addProperty("buildType", buildType);
      data.addProperty("startTime", start.getMillis());
      data.addProperty("endTime", end.getMillis());

      RequestEntity entity = new StringRequestEntity(data.toString(), "application/json", "UTF-8");
      method.setRequestEntity(entity);
      client.executeMethod(method);
      JsonObject result =
          new JsonParser().parse(method.getResponseBodyAsString()).getAsJsonObject();
      String jobUuid = result.get("uuid").getAsString();
      waitForJob(jobUuid);
    } catch (HttpException e) {
      logger.error("getSegments error", e);
    } catch (JsonSyntaxException e) {
      logger.error("getSegments error", e);
    } catch (IOException e) {
      logger.error("getSegments error", e);
    }

    logger.info("Finish building segment (" + buildType + "): " + start + " - " + end);
  }

  private String getJobStatus(String jobUuid) {
    GetMethod method = new GetMethod(KYLIN_URL + "/api/jobs/" + jobUuid);

    String status = null;
    try {
      client.executeMethod(method);
      JsonObject result =
          new JsonParser().parse(method.getResponseBodyAsString()).getAsJsonObject();
      status = result.get("job_status").getAsString();
    } catch (HttpException e) {
      logger.error("getJobStatus error", e);
    } catch (JsonSyntaxException e) {
      logger.error("getSegments error", e);
    } catch (IOException e) {
      logger.error("getJobStatus error", e);
    } finally {
      method.releaseConnection();
    }

    logger.debug("Job status: " + jobUuid + ": " + status);

    return status;
  }

  private void waitForJob(String jobUuid) {
    try {
      while (getJobStatus(jobUuid) != "FINISHED") {
        Thread.sleep(10000);
      }
    } catch (InterruptedException ex) {
      Thread.currentThread().interrupt();
    }
  }
}
