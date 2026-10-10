import 'package:flutter_test/flutter_test.dart';
import 'package:worklog/features/gym/domain/body_stat.dart';

void main() {
  test('body stat keeps height and target weight in saved history', () {
    final stat = BodyStat(
      id: 'stat-1',
      date: DateTime(2026, 10, 10),
      weight: 72.5,
      heightCm: 175,
      targetWeightKg: 68,
      waistCm: 82,
    );

    final writable = stat.toWritableMap();
    expect(writable['height_cm'], 175);
    expect(writable['target_weight_kg'], 68);

    final restored = BodyStat.fromMap({
      'id': 'stat-1',
      ...writable,
    });
    expect(restored.heightCm, 175);
    expect(restored.targetWeightKg, 68);
    expect(restored.weight, 72.5);
  });
}
