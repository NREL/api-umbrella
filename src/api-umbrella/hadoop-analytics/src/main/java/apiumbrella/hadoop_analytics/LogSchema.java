package apiumbrella.hadoop_analytics;

import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;

import org.apache.avro.Schema;
import org.apache.avro.Schema.Type;

public class LogSchema {
  private Schema schema;
  private HashMap<String, Schema.Type> fieldTypes;
  private ArrayList<String> fieldNames;
  private HashSet<String> partitionFields = new HashSet<String>();
  private ArrayList<String> nonPartitionFields = new ArrayList<String>();
  private HashSet<String> shortFields = new HashSet<String>();

  public LogSchema() {
    fieldTypes = new HashMap<String, Schema.Type>();
    fieldNames = new ArrayList<String>();
    for (Schema.Field field : getSchema().getFields()) {
      Schema.Type type = field.schema().getType();
      if (type == Schema.Type.UNION) {
        for (Schema unionSchema : field.schema().getTypes()) {
          if (unionSchema.getType() != Schema.Type.NULL) {
            type = unionSchema.getType();
            break;
          }
        }
      }

      fieldTypes.put(field.name(), type);
      fieldNames.add(field.name());
    }

    // Explicitly define which fields we'll be partitioning by, since these
    // don't need to be sorted in the output file (since they're part of the
    // file path, it's duplicative to store this data in the file).
    partitionFields.add("request_at_tz_year");
    partitionFields.add("request_at_tz_month");
    partitionFields.add("request_at_tz_date");

    for (String name : fieldNames) {
      if (!partitionFields.contains(name)) {
        nonPartitionFields.add(name);
      }
    }

    // Define fields we want to store as short/smallints. Since Avro doesn't
    // support these in its schema, but ORC does, we need to explicitly list
    // these.
    shortFields.add("request_at_tz_year");
    shortFields.add("request_at_tz_month");
    shortFields.add("request_at_tz_hour");
    shortFields.add("request_at_minute");
    shortFields.add("response_status");
  }

  protected Schema getSchema() {
    if (schema == null) {
      InputStream is = App.class.getClassLoader().getResourceAsStream("log.avsc");
      try {
        schema = new Schema.Parser().parse(is);
      } catch (IOException e) {
        e.printStackTrace();
        System.exit(1);
      }
    }
    return schema;
  }

  protected Type getFieldType(String field) {
    return fieldTypes.get(field);
  }

  protected ArrayList<String> getFieldNames() {
    return fieldNames;
  }

  protected HashSet<String> getPartitioFields() {
    return partitionFields;
  }

  protected ArrayList<String> getNonPartitionFields() {
    return nonPartitionFields;
  }
}
