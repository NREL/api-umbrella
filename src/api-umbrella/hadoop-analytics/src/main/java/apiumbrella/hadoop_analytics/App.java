package apiumbrella.hadoop_analytics;

import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

public class App {
  public App() {
    Runnable convert = new ConvertLiveDataToOrc();
    ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
    scheduler.scheduleAtFixedRate(convert, 0, 1, TimeUnit.MINUTES);
  }

  public static void main(String[] args) {
    new App();
  }
}
