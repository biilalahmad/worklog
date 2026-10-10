/// Minimal, dependency-free CSV builder (RFC 4180-ish): a field is
/// quoted whenever it contains a comma, quote, or newline, and any
/// quote inside it is doubled. No external package needed for
/// something this small.
class CsvWriter {
  final List<List<String>> _rows = [];

  void addRow(List<Object?> fields) {
    _rows.add(fields.map(_cell).toList());
  }

  static String _cell(Object? value) {
    final text = value?.toString() ?? '';
    final needsQuoting = text.contains(',') || text.contains('"') || text.contains('\n') || text.contains('\r');
    if (!needsQuoting) return text;
    final escaped = text.replaceAll('"', '""');
    return '"$escaped"';
  }

  String build() => _rows.map((r) => r.join(',')).join('\r\n');
}

/// Parses a simple CSV string back into rows of raw string cells,
/// handling quoted fields (including embedded commas/newlines) and
/// doubled-quote escaping. Good enough for the small, well-formed
/// exports this app produces and typical spreadsheet-exported CSVs —
/// not a full RFC 4180 implementation (no support for stray/malformed
/// quoting).
List<List<String>> parseCsv(String content) {
  final rows = <List<String>>[];
  var row = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;
  var i = 0;
  final n = content.length;

  void endField() {
    row.add(buffer.toString());
    buffer.clear();
  }

  void endRow() {
    endField();
    rows.add(row);
    row = [];
  }

  while (i < n) {
    final ch = content[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < n && content[i + 1] == '"') {
          buffer.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      buffer.write(ch);
      i++;
      continue;
    }
    switch (ch) {
      case '"':
        inQuotes = true;
        i++;
      case ',':
        endField();
        i++;
      case '\r':
        i++; // skip, \n (or end) closes the row
      case '\n':
        endRow();
        i++;
      default:
        buffer.write(ch);
        i++;
    }
  }
  // Last field/row if the content didn't end with a newline.
  if (buffer.isNotEmpty || row.isNotEmpty) endRow();
  return rows.where((r) => r.isNotEmpty && !(r.length == 1 && r[0].isEmpty)).toList();
}
