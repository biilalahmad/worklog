import '../../../core/utils/date_keys.dart';

class WaterLog {
  final String id;
  final DateTime date;
  final int milliliters;

  const WaterLog(
      {required this.id, required this.date, required this.milliliters});

  factory WaterLog.fromMap(Map<String, dynamic> map) => WaterLog(
        id: map['id'] as String,
        date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
        milliliters: (map['milliliters'] as num?)?.toInt() ?? 250,
      );

  Map<String, dynamic> toWritableMap() => {
        'date': DateKeys.day(date),
        'milliliters': milliliters,
      };
}
