import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/widgets/app_select_field.dart';
import '../../domain/food.dart';
import '../../domain/meal_entry.dart';
import '../../data/food_lookup_service.dart';
import '../providers/gym_providers.dart';

class MealFormScreen extends ConsumerStatefulWidget {
  const MealFormScreen({super.key});

  @override
  ConsumerState<MealFormScreen> createState() => _MealFormScreenState();
}

class _MealFormScreenState extends ConsumerState<MealFormScreen> {
  final _nameCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '1');
  final _calCtrl = TextEditingController();
  final _proCtrl = TextEditingController();
  final _carbCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  MealType _mealType = MealType.snack;
  Food? _selectedFood;
  String _foodQuery = '';
  String? _searchedFoodQuery;
  Timer? _searchDebounce;
  double _baseCalories = 0;
  double _baseProtein = 0;
  double _baseCarbs = 0;
  double _baseFat = 0;
  bool _saving = false;

  double get _quantity => double.tryParse(_quantityCtrl.text.trim()) ?? 0;

  String _formatAmount(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  void _onFoodQueryChanged(String value) {
    _foodQuery = value.trim();
    _selectedFood = null;
    _searchDebounce?.cancel();
    if (_foodQuery.length < 2) {
      _searchedFoodQuery = null;
      return;
    }
    final query = _foodQuery;
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted || query != _foodQuery) return;
      setState(() => _searchedFoodQuery = query);
    });
  }

  void _updateDisplayedNutrition() {
    final quantity = _quantity;
    if (quantity <= 0) return;
    _calCtrl.text = _formatAmount(_baseCalories * quantity);
    _proCtrl.text = _formatAmount(_baseProtein * quantity);
    _carbCtrl.text = _formatAmount(_baseCarbs * quantity);
    _fatCtrl.text = _formatAmount(_baseFat * quantity);
  }

  void _captureBaseValue(String value, void Function(double) updateBase) {
    final amount = double.tryParse(value.trim());
    final quantity = _quantity;
    if (amount != null && quantity > 0) updateBase(amount / quantity);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _nameCtrl.dispose();
    _quantityCtrl.dispose();
    _calCtrl.dispose();
    _proCtrl.dispose();
    _carbCtrl.dispose();
    _fatCtrl.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupBarcode() async {
    final barcode = _barcodeCtrl.text.trim();
    if (barcode.isEmpty) return;
    setState(() => _saving = true);
    try {
      final result =
          await ref.read(foodLookupServiceProvider).byBarcode(barcode);
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Food not found. You can enter it manually.')),
        );
        return;
      }
      _applyFood(_toFood(result));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Food lookup failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _applyFood(Food f) {
    _selectedFood = f;
    _nameCtrl.text = f.name;
    _foodQuery = '';
    _searchedFoodQuery = null;
    _baseCalories = f.calories;
    _baseProtein = f.protein;
    _baseCarbs = f.carbs;
    _baseFat = f.fat;
    _updateDisplayedNutrition();
    setState(() {});
  }

  Food _toFood(FoodLookupResult result) => Food(
        id: '',
        name: result.brand == null || result.brand!.trim().isEmpty
            ? result.name
            : '${result.brand} ${result.name}',
        barcode: result.barcode.isEmpty ? null : result.barcode,
        source: 'open_food_facts',
        calories: result.caloriesPer100g,
        protein: result.proteinPer100g,
        carbs: result.carbsPer100g,
        fat: result.fatPer100g,
      );

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a food name to add this meal.')),
      );
      return;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final quantity = double.tryParse(_quantityCtrl.text.trim());
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a quantity greater than zero.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final qty = quantity;
      final totalCal = double.tryParse(_calCtrl.text.trim()) ?? 0;
      final totalPro = double.tryParse(_proCtrl.text.trim()) ?? 0;
      final totalCarb = double.tryParse(_carbCtrl.text.trim()) ?? 0;
      final totalFat = double.tryParse(_fatCtrl.text.trim()) ?? 0;
      final baseCal = totalCal / qty;
      final basePro = totalPro / qty;
      final baseCarb = totalCarb / qty;
      final baseFat = totalFat / qty;

      String? foodId = _selectedFood?.id;
      if (foodId == null || foodId.isEmpty) {
        foodId = await ref.read(dietRepositoryProvider).addFood(Food(
              id: '',
              name: name,
              barcode: _selectedFood?.barcode ??
                  (_barcodeCtrl.text.trim().isEmpty
                      ? null
                      : _barcodeCtrl.text.trim()),
              source: _selectedFood?.source ??
                  (_barcodeCtrl.text.trim().isEmpty
                      ? 'manual'
                      : 'open_food_facts'),
              calories: baseCal,
              protein: basePro,
              carbs: baseCarb,
              fat: baseFat,
            ));
        ref.invalidate(foodsListProvider);
      }

      await ref.read(dietRepositoryProvider).addMeal(MealEntry(
            id: '',
            date: now,
            mealType: _mealType,
            foodId: foodId,
            foodName: name,
            quantity: qty,
            calories: totalCal,
            protein: totalPro,
            carbs: totalCarb,
            fat: totalFat,
          ));
      ref.invalidate(mealsForDateProvider(today));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(Failure.from(e).message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveFoodForLater() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a food name first.')),
      );
      return;
    }
    final quantity = _quantity;
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a quantity greater than zero.')),
      );
      return;
    }
    final existing = ref.read(foodsListProvider).valueOrNull ?? const <Food>[];
    if (existing
        .any((food) => food.name.trim().toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('This food is already in your saved foods.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await ref.read(dietRepositoryProvider).addFood(Food(
            id: '',
            name: name,
            barcode: _selectedFood?.barcode,
            source: _selectedFood?.source ?? 'manual',
            calories: (double.tryParse(_calCtrl.text.trim()) ?? 0) / quantity,
            protein: (double.tryParse(_proCtrl.text.trim()) ?? 0) / quantity,
            carbs: (double.tryParse(_carbCtrl.text.trim()) ?? 0) / quantity,
            fat: (double.tryParse(_fatCtrl.text.trim()) ?? 0) / quantity,
          ));
      ref.invalidate(foodsListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Food saved. It will appear in suggestions next time.')),
        );
        _selectedFood = Food(
          id: id,
          name: name,
          barcode: _selectedFood?.barcode,
          source: _selectedFood?.source ?? 'manual',
          calories: (double.tryParse(_calCtrl.text.trim()) ?? 0) / quantity,
          protein: (double.tryParse(_proCtrl.text.trim()) ?? 0) / quantity,
          carbs: (double.tryParse(_carbCtrl.text.trim()) ?? 0) / quantity,
          fat: (double.tryParse(_fatCtrl.text.trim()) ?? 0) / quantity,
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(Failure.from(error).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foodsAsync = ref.watch(foodsListProvider);
    final remoteFoodsAsync =
        _searchedFoodQuery != null && _searchedFoodQuery == _foodQuery.trim()
            ? ref.watch(foodNameSearchProvider(_searchedFoodQuery!))
            : null;
    final savedMatches = [
      ...(foodsAsync.valueOrNull ?? const <Food>[]),
      ...searchCommonFoods(_foodQuery),
    ]
        .where((food) =>
            _foodQuery.isNotEmpty &&
            food.name.toLowerCase().contains(_foodQuery.toLowerCase()))
        .fold<Map<String, Food>>({}, (unique, food) {
          unique.putIfAbsent(food.name.toLowerCase(), () => food);
          return unique;
        })
        .values
        .take(8)
        .toList();
    final onlineMatches =
        (remoteFoodsAsync?.valueOrNull ?? const <FoodLookupResult>[])
            .map(_toFood)
            .toList();
    final foodSuggestions = [...savedMatches, ...onlineMatches]
        .fold<Map<String, Food>>({}, (unique, food) {
          unique.putIfAbsent(food.name.trim().toLowerCase(), () => food);
          return unique;
        })
        .values
        .take(8)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Add Meal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppSelectField<MealType>(
            value: _mealType,
            label: 'Meal',
            options: MealType.values
                .map((m) => AppSelectOption(value: m, label: m.label))
                .toList(),
            onChanged: (v) => setState(() => _mealType = v ?? MealType.snack),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Food name',
              hintText: 'Search foods or enter one manually',
              prefixIcon: Icon(Icons.restaurant_outlined, size: 20),
            ),
            onChanged: (value) => setState(() {
              _onFoodQueryChanged(value);
            }),
          ),
          if (_foodQuery.trim().length >= 2) ...[
            _FoodSuggestionList(
              foods: foodSuggestions,
              isLoading: _searchedFoodQuery != _foodQuery.trim() ||
                  (remoteFoodsAsync?.isLoading ?? false),
              onSelected: _applyFood,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _barcodeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Barcode (optional)',
                    hintText: 'Lookup packaged food',
                    prefixIcon: Icon(Icons.qr_code_scanner_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _saving ? null : _lookupBarcode,
                tooltip: 'Lookup food',
                icon: const Icon(Icons.search_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _quantityCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(_updateDisplayedNutrition),
            decoration: const InputDecoration(
              labelText: 'Quantity (× values below)',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Nutrition totals for ${_formatAmount(_quantity)} ${_quantity == 1 ? 'serving' : 'servings'}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _calCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) =>
                      _captureBaseValue(value, (v) => _baseCalories = v),
                  decoration: const InputDecoration(labelText: 'Calories'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _proCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) =>
                      _captureBaseValue(value, (v) => _baseProtein = v),
                  decoration: const InputDecoration(labelText: 'Protein (g)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _carbCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) =>
                      _captureBaseValue(value, (v) => _baseCarbs = v),
                  decoration: const InputDecoration(labelText: 'Carbs (g)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _fatCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) =>
                      _captureBaseValue(value, (v) => _baseFat = v),
                  decoration: const InputDecoration(labelText: 'Fat (g)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _saving ? null : _saveFoodForLater,
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('Save food for later'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Add Meal'),
          ),
        ],
      ),
    );
  }
}

class _FoodSuggestionList extends StatelessWidget {
  const _FoodSuggestionList({
    required this.foods,
    required this.isLoading,
    required this.onSelected,
  });

  final List<Food> foods;
  final bool isLoading;
  final ValueChanged<Food> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Text('Food suggestions',
                    style: Theme.of(context).textTheme.labelLarge),
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: LinearProgressIndicator(),
                ),
              for (final food in foods)
                ListTile(
                  dense: true,
                  title: Text(food.name),
                  subtitle: Text(
                      '${food.calories.toStringAsFixed(0)} kcal · P ${food.protein.toStringAsFixed(1)} g'),
                  onTap: () => onSelected(food),
                ),
              if (foods.isEmpty && !isLoading)
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: Text(
                      'No suggestions yet. You can add this food manually.'),
                ),
            ],
          ),
        ),
      );
}
