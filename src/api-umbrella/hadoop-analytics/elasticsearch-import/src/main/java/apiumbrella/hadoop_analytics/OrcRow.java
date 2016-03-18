package apiumbrella.hadoop_analytics;

// From https://gist.github.com/omalley/ccabae7cccac28f64812
public class OrcRow {
  public Object[] columns;

  OrcRow(int colCount) {
    columns = new Object[colCount];
  }

  void setFieldValue(int FieldIndex, Object value) {
    columns[FieldIndex] = value;
  }

  void setNumFields(int newSize) {
    if (newSize != columns.length) {
      Object[] oldColumns = columns;
      columns = new Object[newSize];
      System.arraycopy(oldColumns, 0, columns, 0, oldColumns.length);
    }
  }
}
