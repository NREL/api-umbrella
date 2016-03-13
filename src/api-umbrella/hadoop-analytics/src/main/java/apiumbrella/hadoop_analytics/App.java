package apiumbrella.hadoop_analytics;

public class App {
  public App() {
    int threads = 1;
    LogConsumerGroup example =
        new LogConsumerGroup("localhost:2181", "mygroup", "api_umbrella_logs");
    example.run(threads);
  }

  public static void main(String[] args) {
    new App();
  }
}
