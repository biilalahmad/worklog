/// A reusable food/ingredient — type once, macros are remembered and
/// suggested from then on (same pattern as exercises/clients).
class Food {
  final String id;
  final String name;
  final String unitLabel;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String? barcode;
  final String source;

  const Food({
    required this.id,
    required this.name,
    this.unitLabel = '100g',
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.barcode,
    this.source = 'manual',
  });

  factory Food.fromMap(Map<String, dynamic> data) {
    return Food(
      id: data['id'] as String,
      name: data['name'] as String? ?? '',
      unitLabel: data['unit_label'] as String? ?? '100g',
      calories: (data['calories'] as num?)?.toDouble() ?? 0,
      protein: (data['protein'] as num?)?.toDouble() ?? 0,
      carbs: (data['carbs'] as num?)?.toDouble() ?? 0,
      fat: (data['fat'] as num?)?.toDouble() ?? 0,
      barcode: data['barcode'] as String?,
      source: data['source'] as String? ?? 'manual',
    );
  }

  Map<String, dynamic> toWritableMap() => {
        'name': name,
        'unit_label': unitLabel,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'barcode': barcode,
        'source': source,
      };
}

/// Approximate common-food entries remain available when network search is
/// unavailable. Values use the same per-100-g basis as Open Food Facts.
const commonStapleFoods = <Food>[
  Food(
      id: '',
      name: 'Whole egg',
      unitLabel: '100 g',
      calories: 143,
      protein: 12.6,
      carbs: 0.7,
      fat: 9.5,
      source: 'common'),
  Food(
      id: '',
      name: 'Boiled egg',
      unitLabel: '100 g',
      calories: 155,
      protein: 12.6,
      carbs: 1.1,
      fat: 10.6,
      source: 'common'),
  Food(
      id: '',
      name: 'Cooked white rice',
      unitLabel: '100 g',
      calories: 130,
      protein: 2.7,
      carbs: 28.2,
      fat: 0.3,
      source: 'common'),
  Food(
      id: '',
      name: 'Cooked chicken breast',
      unitLabel: '100 g',
      calories: 165,
      protein: 31,
      carbs: 0,
      fat: 3.6,
      source: 'common'),
];

List<Food> searchCommonFoods(String query) {
  final clean = query.trim().toLowerCase();
  if (clean.isEmpty) return const [];
  return commonStapleFoods
      .where((food) => food.name.toLowerCase().contains(clean))
      .toList(growable: false);
}
