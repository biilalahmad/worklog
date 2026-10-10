/// Case-insensitive partial and near-match search for short user-facing lists.
bool matchesSearch(String value, String query) {
  final normalizedQuery = _normalize(query);
  if (normalizedQuery.isEmpty) {
    final rawQuery = query.trim().toLowerCase();
    return rawQuery.isEmpty || value.toLowerCase().contains(rawQuery);
  }

  final normalizedValue = _normalize(value);
  if (normalizedValue.contains(normalizedQuery)) return true;

  final queryTokens = normalizedQuery.split(' ');
  final valueTokens = normalizedValue.split(' ');
  return queryTokens.every((queryToken) => valueTokens.any((valueToken) {
        if (valueToken.startsWith(queryToken)) return true;
        if (queryToken.length < 5 || valueToken.length < 5) return false;
        return _editDistanceAtMostOne(queryToken, valueToken);
      }));
}

String _normalize(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

bool _editDistanceAtMostOne(String first, String second) {
  if ((first.length - second.length).abs() > 1) return false;
  var i = 0;
  var j = 0;
  var edits = 0;
  while (i < first.length && j < second.length) {
    if (first[i] == second[j]) {
      i++;
      j++;
      continue;
    }
    if (++edits > 1) return false;
    if (i + 1 < first.length &&
        j + 1 < second.length &&
        first[i] == second[j + 1] &&
        first[i + 1] == second[j]) {
      i += 2;
      j += 2;
    } else if (first.length > second.length) {
      i++;
    } else if (second.length > first.length) {
      j++;
    } else {
      i++;
      j++;
    }
  }
  if (i < first.length || j < second.length) edits++;
  return edits <= 1;
}
