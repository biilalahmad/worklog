enum MealType { breakfast, lunch, dinner, snack }

extension MealTypeX on MealType {
  String get asString => toString().split('.').last;
  String get label {
    switch (this) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
      case MealType.snack:
        return 'Snack';
    }
  }

  static MealType fromString(String? v) => MealType.values
      .firstWhere((m) => m.asString == v, orElse: () => MealType.snack);
}

/// A logged meal. Macro values are snapshotted at log time (never a
/// live join to `foods`), so editing a food later never rewrites
/// history.
class MealEntry {
  final String id;
  final DateTime date;
  final MealType mealType;
  final String? foodId;
  final String foodName;
  final double quantity;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String? notes;

  const MealEntry({
    required this.id,
    required this.date,
    this.mealType = MealType.snack,
    this.foodId,
    required this.foodName,
    this.quantity = 1,
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.notes,
  });

  factory MealEntry.fromMap(Map<String, dynamic> data) {
    return MealEntry(
      id: data['id'] as String,
      date: DateTime.tryParse(data['date'] as String? ?? '') ?? DateTime.now(),
      mealType: MealTypeX.fromString(data['meal_type'] as String?),
      foodId: data['food_id'] as String?,
      foodName: data['food_name'] as String? ?? '',
      quantity: (data['quantity'] as num?)?.toDouble() ?? 1,
      calories: (data['calories'] as num?)?.toDouble() ?? 0,
      protein: (data['protein'] as num?)?.toDouble() ?? 0,
      carbs: (data['carbs'] as num?)?.toDouble() ?? 0,
      fat: (data['fat'] as num?)?.toDouble() ?? 0,
      notes: data['notes'] as String?,
    );
  }

  Map<String, dynamic> toWritableMap() => {
        'date': date.toIso8601String(),
        'meal_type': mealType.asString,
        'food_id': foodId,
        'food_name': foodName,
        'quantity': quantity,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'notes': notes,
      };
}
