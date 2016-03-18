package apiumbrella.hadoop_analytics;

import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class App {
  final Logger logger = LoggerFactory.getLogger(App.class);

  public App() {
    Runnable convert = new ConvertLiveDataToOrc(this);
    ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);
    scheduler.scheduleAtFixedRate(convert, 0, 30, TimeUnit.SECONDS);
  }

  public static void main(String[] args) {
    new App();
  }
}
