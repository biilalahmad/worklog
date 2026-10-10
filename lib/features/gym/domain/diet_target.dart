class DietTarget {
  final double dailyCalories;
  final double dailyProtein;
  final double dailyCarbs;
  final double dailyFat;

  const DietTarget({
    this.dailyCalories = 2200,
    this.dailyProtein = 150,
    this.dailyCarbs = 220,
    this.dailyFat = 70,
  });

  factory DietTarget.fromMap(Map<String, dynamic> data) {
    return DietTarget(
      dailyCalories: (data['daily_calories'] as num?)?.toDouble() ?? 2200,
      dailyProtein: (data['daily_protein'] as num?)?.toDouble() ?? 150,
      dailyCarbs: (data['daily_carbs'] as num?)?.toDouble() ?? 220,
      dailyFat: (data['daily_fat'] as num?)?.toDouble() ?? 70,
    );
  }

  Map<String, dynamic> toWritableMap() => {
        'daily_calories': dailyCalories,
        'daily_protein': dailyProtein,
        'daily_carbs': dailyCarbs,
        'daily_fat': dailyFat,
      };
}
