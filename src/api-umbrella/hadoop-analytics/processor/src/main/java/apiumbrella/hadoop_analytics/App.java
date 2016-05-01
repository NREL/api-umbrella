package apiumbrella.hadoop_analytics;

import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

import org.joda.time.DateTimeZone;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class App {
  protected static DateTimeZone TIMEZONE =
      DateTimeZone.forID(System.getProperty("apiumbrella.timezone", "UTC"));
  final Logger logger = LoggerFactory.getLogger(App.class);

  public App() {
    Runnable convert = new ConvertLiveDataToOrc(this);
    ScheduledExecutorService convertScheduler = Executors.newScheduledThreadPool(1);
    convertScheduler.scheduleAtFixedRate(convert, 0, 30, TimeUnit.SECONDS);

    Runnable refresh = new RefreshKylin(this);
    ScheduledExecutorService refreshScheduler = Executors.newScheduledThreadPool(1);
    refreshScheduler.scheduleAtFixedRate(refresh, 0, 1, TimeUnit.HOURS);
  }

  public static void main(String[] args) {
    new App();
  }
}
