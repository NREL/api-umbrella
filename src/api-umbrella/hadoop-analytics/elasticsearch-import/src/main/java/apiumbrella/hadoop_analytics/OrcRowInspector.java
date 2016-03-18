package apiumbrella.hadoop_analytics;

import java.util.ArrayList;
import java.util.List;

import org.apache.hadoop.hive.serde2.objectinspector.SettableStructObjectInspector;
import org.apache.hadoop.hive.serde2.objectinspector.StructField;

// From https://gist.github.com/omalley/ccabae7cccac28f64812
public class OrcRowInspector extends SettableStructObjectInspector {
  private List<StructField> fields;

  public OrcRowInspector(List<StructField> fields) {
    super();
    this.fields = fields;
  }

  @Override
  public List<StructField> getAllStructFieldRefs() {
    return fields;
  }

  @Override
  public StructField getStructFieldRef(String s) {
    for (StructField field : fields) {
      if (field.getFieldName().equalsIgnoreCase(s)) {
        return field;
      }
    }
    return null;
  }

  @Override
  public Object getStructFieldData(Object object, StructField field) {
    if (object == null) {
      return null;
    }
    int offset = ((OrcField) field).offset;
    OrcRow struct = (OrcRow) object;
    if (offset >= struct.columns.length) {
      return null;
    }

    return struct.columns[offset];
  }

  @Override
  public List<Object> getStructFieldsDataAsList(Object object) {
    if (object == null) {
      return null;
    }
    OrcRow struct = (OrcRow) object;
    List<Object> result = new ArrayList<Object>(struct.columns.length);
    for (Object child : struct.columns) {
      result.add(child);
    }
    return result;
  }

  @Override
  public String getTypeName() {
    StringBuilder buffer = new StringBuilder();
    buffer.append("struct<");
    for (int i = 0; i < fields.size(); ++i) {
      StructField field = fields.get(i);
      if (i != 0) {
        buffer.append(",");
      }
      buffer.append(field.getFieldName());
      buffer.append(":");
      buffer.append(field.getFieldObjectInspector().getTypeName());
    }
    buffer.append(">");
    return buffer.toString();
  }

  @Override
  public Category getCategory() {
    return Category.STRUCT;
  }

  @Override
  public Object create() {
    return new OrcRow(0);
  }

  @Override
  public Object setStructFieldData(Object struct, StructField field, Object fieldValue) {
    OrcRow orcStruct = (OrcRow) struct;
    int offset = ((OrcField) field).offset;
    // if the offset is bigger than our current number of fields, grow it
    if (orcStruct.columns.length <= offset) {
      orcStruct.setNumFields(offset + 1);
    }
    orcStruct.setFieldValue(offset, fieldValue);
    return struct;
  }

  @Override
  public boolean equals(Object o) {
    if (o == null || o.getClass() != getClass()) {
      return false;
    } else if (o == this) {
      return true;
    } else {
      List<StructField> other = ((OrcRowInspector) o).fields;
      if (other.size() != fields.size()) {
        return false;
      }
      for (int i = 0; i < fields.size(); ++i) {
        StructField left = other.get(i);
        StructField right = fields.get(i);
        if (!(left.getFieldName().equalsIgnoreCase(right.getFieldName())
            && left.getFieldObjectInspector().equals(right.getFieldObjectInspector()))) {
          return false;
        }
      }
      return true;
    }
  }
}
