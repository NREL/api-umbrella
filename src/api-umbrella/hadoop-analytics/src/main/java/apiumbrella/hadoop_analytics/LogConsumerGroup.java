package apiumbrella.hadoop_analytics;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

import kafka.consumer.Consumer;
import kafka.consumer.ConsumerConfig;
import kafka.consumer.KafkaStream;
import kafka.javaapi.consumer.ConsumerConnector;

public class LogConsumerGroup {
  private final ConsumerConnector consumer;
  private final String topic;
  private ExecutorService executor;

  public LogConsumerGroup(String zookeeper, String groupId, String topic) {
    Properties properties = new Properties();
    properties.put("zookeeper.connect", zookeeper);
    properties.put("group.id", groupId);
    properties.put("zookeeper.session.timeout.ms", "500");
    properties.put("zookeeper.sync.time.ms", "250");
    properties.put("auto.commit.interval.ms", "1000");

    consumer = Consumer.createJavaConsumerConnector(new ConsumerConfig(properties));
    this.topic = topic;
  }

  public void shutdown() {
    if (consumer != null)
      consumer.shutdown();
    if (executor != null)
      executor.shutdown();
    try {
      if (!executor.awaitTermination(5000, TimeUnit.MILLISECONDS)) {
        System.out
            .println("Timed out waiting for consumer threads to shut down, exiting uncleanly");
      }
    } catch (InterruptedException e) {
      System.out.println("Interrupted during shutdown, exiting uncleanly");
    }
  }

  public void run(int threadCount) {
    Map<String, Integer> topicCount = new HashMap<String, Integer>();
    topicCount.put(topic, threadCount);

    Map<String, List<KafkaStream<byte[], byte[]>>> consumerStreams =
        consumer.createMessageStreams(topicCount);
    List<KafkaStream<byte[], byte[]>> streams = consumerStreams.get(topic);

    executor = Executors.newFixedThreadPool(threadCount);

    int threadNumber = 0;
    for (final KafkaStream<byte[], byte[]> stream : streams) {
      executor.submit(new LogConsumer(stream, threadNumber));
      threadNumber++;
    }
  }
}
