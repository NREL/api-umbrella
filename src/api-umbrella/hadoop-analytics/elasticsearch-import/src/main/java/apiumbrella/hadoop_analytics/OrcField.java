package apiumbrella.hadoop_analytics;

import org.apache.hadoop.hive.serde2.objectinspector.ObjectInspector;
import org.apache.hadoop.hive.serde2.objectinspector.StructField;

// From https://gist.github.com/omalley/ccabae7cccac28f64812
public class OrcField implements StructField {
  private final String name;
  private final ObjectInspector inspector;
  final int offset;

  OrcField(String name, ObjectInspector inspector, int offset) {
    this.name = name;
    this.inspector = inspector;
    this.offset = offset;
  }

  @Override
  public String getFieldName() {
    return name;
  }

  @Override
  public ObjectInspector getFieldObjectInspector() {
    return inspector;
  }

  @Override
  public int getFieldID() {
    return offset;
  }

  @Override
  public String getFieldComment() {
    return null;
  }
}
