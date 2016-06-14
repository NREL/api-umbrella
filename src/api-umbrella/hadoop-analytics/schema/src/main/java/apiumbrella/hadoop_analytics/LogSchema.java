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
  private ArrayList<String> partitionFields = new ArrayList<String>();
  private ArrayList<String> nonPartitionFields = new ArrayList<String>();
  private ArrayList<String> livePartitionFields = new ArrayList<String>();
  private ArrayList<String> liveNonPartitionFields = new ArrayList<String>();
  private HashSet<String> shortFields = new HashSet<String>();
  private HashSet<String> dateFields = new HashSet<String>();

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
    partitionFields.add("timestamp_tz_year");
    partitionFields.add("timestamp_tz_month");
    partitionFields.add("timestamp_tz_week");
    partitionFields.add("timestamp_tz_date");

    livePartitionFields.add("timestamp_tz_date");
    livePartitionFields.add("timestamp_tz_hour_minute");
    fieldTypes.put("timestamp_tz_hour_minute", Schema.Type.STRING);

    for (String name : fieldNames) {
      if (!partitionFields.contains(name)) {
        nonPartitionFields.add(name);
      }

      if (!livePartitionFields.contains(name)) {
        liveNonPartitionFields.add(name);
      }
    }

    // Define fields we want to store as short/smallints. Since Avro doesn't
    // support these in its schema, but ORC does, we need to explicitly list
    // these.
    shortFields.add("response_status");

    dateFields.add("timestamp_tz_year");
    dateFields.add("timestamp_tz_month");
    dateFields.add("timestamp_tz_week");
    dateFields.add("timestamp_tz_date");
  }

  protected Schema getSchema() {
    if (schema == null) {
      InputStream is = Schema.class.getClassLoader().getResourceAsStream("log.avsc");
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

  protected boolean isFieldTypeShort(String field) {
    return shortFields.contains(field);
  }

  protected String getFieldHiveType(String field) {
    Type type = getFieldType(field);
    if (type == Schema.Type.INT) {
      if (isFieldTypeShort(field)) {
        return "SMALLINT";
      } else {
        return "INT";
      }
    } else if (type == Schema.Type.LONG) {
      return "BIGINT";
    } else if (type == Schema.Type.DOUBLE) {
      return "DOUBLE";
    } else if (type == Schema.Type.BOOLEAN) {
      return "BOOLEAN";
    } else if (type == Schema.Type.STRING) {
      if (dateFields.contains(field)) {
        return "DATE";
      } else {
        return "STRING";
      }
    } else {
      return null;
    }
  }

  protected ArrayList<String> getFieldNames() {
    return fieldNames;
  }

  protected ArrayList<String> getPartitionFieldsList() {
    return partitionFields;
  }

  protected ArrayList<String> getNonPartitionFieldsList() {
    return nonPartitionFields;
  }

  protected ArrayList<String> getLivePartitionFieldsList() {
    return livePartitionFields;
  }

  protected ArrayList<String> getLiveNonPartitionFieldsList() {
    return liveNonPartitionFields;
  }
}
