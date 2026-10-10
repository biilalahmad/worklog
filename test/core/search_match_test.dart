import 'package:flutter_test/flutter_test.dart';
import 'package:worklog/core/utils/search_match.dart';

void main() {
  test('search is case-insensitive and supports partial matches', () {
    expect(matchesSearch('Ahmad Studio', 'AHM'), isTrue);
    expect(matchesSearch('Video editing', 'edit'), isTrue);
  });

  test('search tolerates a one-character typo in longer names', () {
    expect(matchesSearch('Ahmad', 'Ahmda'), isTrue);
    expect(matchesSearch('Ahmad', 'Zzzzz'), isFalse);
  });

  test('empty query matches without changing existing filtering behavior', () {
    expect(matchesSearch('Any client', '  '), isTrue);
  });
}
