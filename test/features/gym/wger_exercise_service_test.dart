import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:worklog/features/gym/data/wger_exercise_service.dart';
import 'package:worklog/features/gym/domain/exercise.dart';

void main() {
  test('maps public Wger metadata and removes duplicate exercise names',
      () async {
    final service = WgerExerciseService(
      client: MockClient((request) async {
        expect(request.url.host, 'wger.de');
        expect(request.url.path, '/api/v2/exerciseinfo/');
        return http.Response(
            jsonEncode({
              'results': [
                {
                  'translations': [
                    {'language': 2, 'name': 'Bench Press'}
                  ],
                  'category': {'name': 'Chest'},
                  'equipment': [
                    {'name': 'Barbell'}
                  ],
                },
                {
                  'translations': [
                    {'language': 2, 'name': 'Bench Press'}
                  ],
                  'category': {'name': 'Chest'},
                  'equipment': [
                    {'name': 'Dumbbell'}
                  ],
                },
              ],
            }),
            200);
      }),
    );

    final results = await service.search('bench');
    expect(results, hasLength(1));
    expect(results.single.name, 'Bench Press');
    expect(results.single.muscleGroup, MuscleGroup.chest);
    expect(results.single.equipment, 'Barbell');
    service.dispose();
  });

  test('does not call Wger for too-short queries', () async {
    final service = WgerExerciseService(client: MockClient((_) async {
      fail('No request expected');
    }));
    expect(await service.search('x'), isEmpty);
    service.dispose();
  });
}
