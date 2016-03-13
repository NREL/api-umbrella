package apiumbrella.hadoop_analytics;

import java.util.ArrayList;
import java.util.Map;

import org.apache.avro.Schema;
import org.apache.avro.generic.GenericData;
import org.apache.avro.generic.GenericRecord;
import org.apache.hive.hcatalog.streaming.DelimitedInputWriter;
import org.apache.hive.hcatalog.streaming.HiveEndPoint;
import org.apache.hive.hcatalog.streaming.RecordWriter;
import org.apache.hive.hcatalog.streaming.StreamingConnection;
import org.apache.hive.hcatalog.streaming.TransactionBatch;

import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import kafka.consumer.ConsumerIterator;
import kafka.consumer.KafkaStream;
import kafka.message.MessageAndMetadata;

public class LogConsumer implements Runnable {
  private static final String HIVE_METASTORE =
      System.getProperty("apiumbrella.hive_metastore", "thrift://127.0.0.1:9083");

  private KafkaStream<byte[], byte[]> stream;
  private int threadNumber;
  private JsonParser parser;

  private StreamingConnection connection;
  private RecordWriter writer;

  private LogSchema logSchema;

  public LogConsumer(KafkaStream<byte[], byte[]> stream, int threadNumber) {
    this.stream = stream;
    this.threadNumber = threadNumber;
    this.parser = new JsonParser();

    logSchema = new LogSchema();

    System.out.println(org.apache.hadoop.hdfs.DistributedFileSystem.class.getName());
  }

  public void run() {
    String dbName = "api_umbrella";
    String tblName = "logs_stream";
    ArrayList<String> partitionVals = new ArrayList<String>(3);
    partitionVals.add("2016");
    partitionVals.add("3");
    partitionVals.add("2016-03-13");
    HiveEndPoint hiveEP = new HiveEndPoint(HIVE_METASTORE, dbName, tblName, partitionVals);

    try {
      connection = hiveEP.newConnection(true);
      ArrayList<String> fieldNames = logSchema.getNonPartitionFields();
      writer =
          new DelimitedInputWriter(fieldNames.toArray(new String[fieldNames.size()]), "\t", hiveEP);
    } catch (Exception e) {
      e.printStackTrace();
    }

    TransactionBatch txnBatch = null;
    try {
      txnBatch = connection.fetchTransactionBatch(10, writer);
      txnBatch.beginNextTransaction();
    } catch (Exception e) {
      e.printStackTrace();
    }

    ConsumerIterator<byte[], byte[]> it = stream.iterator();
    int counter = 0;
    while (it.hasNext()) {
      MessageAndMetadata<byte[], byte[]> record = it.next();
      try {
        JsonObject data = parser.parse(new String(record.message())).getAsJsonObject();
        GenericRecord log = new GenericData.Record(logSchema.getSchema());
        for (Map.Entry<String, JsonElement> entry : data.entrySet()) {
          String key = entry.getKey();
          JsonElement value = entry.getValue();

          // Skip setting anything if the value is null.
          if (value == null || value.isJsonNull()) {
            continue;
          }

          try {
            Schema.Type type = logSchema.getFieldType(key);
            if (type == Schema.Type.INT) {
              log.put(key, value.getAsInt());
            } else if (type == Schema.Type.DOUBLE) {
              log.put(key, value.getAsDouble());
            } else if (type == Schema.Type.BOOLEAN) {
              log.put(key, value.getAsBoolean());
            } else {
              log.put(key, value.getAsString());
            }
          } catch (Exception e) {
            System.out.println("Error on field: " + key);
            System.out.println(e.getMessage());
            throw (e);
          }
        }

        StringBuilder line = new StringBuilder();
        for (int i = 0; i < logSchema.getNonPartitionFields().size(); i++) {
          String field = logSchema.getNonPartitionFields().get(i);
          Object value = log.get(field);
          if (i > 0) {
            line.append("\t");
          }
          line.append(value);
        }

        counter++;
        System.out.println(line);
        txnBatch.write(line.toString().getBytes());

        if (counter >= 100) {
          counter = 0;
          txnBatch.commit();

          if (txnBatch.remainingTransactions() == 0) {
            txnBatch.close();
            txnBatch = connection.fetchTransactionBatch(10, writer);
          }
          txnBatch.beginNextTransaction();
        }
      } catch (Exception e) {
        e.printStackTrace();
      }
    }
    System.out.println("Shutting down thread: " + threadNumber);
  }
}
