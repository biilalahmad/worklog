import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worklog/features/gym/data/food_lookup_service.dart';
import 'package:worklog/features/gym/domain/food.dart';
import 'package:worklog/features/gym/presentation/providers/gym_providers.dart';
import 'package:worklog/features/gym/presentation/screens/meal_form_screen.dart';

void main() {
  testWidgets('combines food suggestions and scales nutrition with quantity',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          foodsListProvider.overrideWith((ref) => Stream.value([
                const Food(
                  id: 'saved-egg',
                  name: 'Whole egg',
                  calories: 143,
                  protein: 12.6,
                ),
              ])),
          foodNameSearchProvider.overrideWith((ref, query) async => [
                const FoodLookupResult(
                  barcode: '123',
                  name: 'Fresh egg',
                  caloriesPer100g: 150,
                ),
              ]),
        ],
        child: const MaterialApp(home: MealFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final foodName = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.labelText == 'Food name');
    await tester.enterText(foodName, 'egg');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('Food suggestions'), findsOneWidget);
    expect(find.text('Whole egg'), findsOneWidget);
    expect(find.text('Fresh egg'), findsOneWidget);
    expect(find.text('Saved foods'), findsNothing);
    expect(find.text('Search online suggestions'), findsNothing);
    expect(find.textContaining('Nutrition values are estimates'), findsNothing);

    await tester.tap(find.text('Whole egg'));
    await tester.pumpAndSettle();
    final quantity = find.byWidgetPredicate((widget) =>
        widget is TextField &&
        widget.decoration?.labelText == 'Quantity (× values below)');
    await tester.enterText(quantity, '2');
    await tester.pump();

    final calories = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.labelText == 'Calories');
    expect(tester.widget<TextField>(calories).controller?.text, '286');
    expect(find.text('Nutrition totals for 2 servings'), findsOneWidget);
  });

  testWidgets('keeps saved food suggestions quiet when online search fails',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          foodsListProvider.overrideWith((ref) => Stream.value([
                const Food(
                  id: 'saved-boiled-egg',
                  name: 'Boiled egg',
                  calories: 155,
                  protein: 12.6,
                ),
              ])),
          foodNameSearchProvider.overrideWith(
              (ref, query) async => throw Exception('no connection')),
        ],
        child: const MaterialApp(home: MealFormScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final foodName = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.labelText == 'Food name');
    await tester.enterText(foodName, 'egg');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('Food suggestions'), findsOneWidget);
    expect(find.text('Boiled egg'), findsOneWidget);
    expect(find.text('Online search unavailable'), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });
}
