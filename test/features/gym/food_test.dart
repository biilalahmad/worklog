import 'package:flutter_test/flutter_test.dart';
import 'package:worklog/features/gym/domain/food.dart';

void main() {
  test('common staple search works offline and uses per-100-g portions', () {
    final eggs = searchCommonFoods('egg');

    expect(eggs.map((food) => food.name), ['Whole egg', 'Boiled egg']);
    expect(eggs.every((food) => food.unitLabel == '100 g'), isTrue);
    expect(eggs.every((food) => food.calories > 0), isTrue);
    expect(searchCommonFoods('cooked white').single.name, 'Cooked white rice');
  });
}
