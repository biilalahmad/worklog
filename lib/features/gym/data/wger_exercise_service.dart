import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/exercise.dart';

class WgerExerciseSuggestion {
  const WgerExerciseSuggestion(
      {required this.name, required this.muscleGroup, required this.equipment});
  final String name;
  final MuscleGroup muscleGroup;
  final String equipment;
}

/// Public metadata only.  Logged exercises are still copied to, and owned by,
/// the user's existing Supabase library.
class WgerExerciseService {
  WgerExerciseService({http.Client? client})
      : _client = client ?? http.Client();
  final http.Client _client;

  Future<List<WgerExerciseSuggestion>> search(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2 || cleanQuery.length > 80) return const [];
    final uri = Uri.https('wger.de', '/api/v2/exerciseinfo/', {
      'language': '2',
      'limit': '20',
      'search': cleanQuery,
    });
    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('Exercise suggestions are unavailable');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = (body['results'] as List? ?? const [])
        .whereType<Map<String, dynamic>>();
    final results = rows
        .map((row) {
          final translations = (row['translations'] as List? ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList();
          final translation = translations
              .cast<Map<String, dynamic>?>()
              .firstWhere(
                (item) => item?['language'] == 2,
                orElse: () => translations.isEmpty ? null : translations.first,
              );
          final name = (translation?['name'] as String?)?.trim() ??
              (row['name'] as String?)?.trim() ??
              '';
          final category = row['category'] as Map<String, dynamic>?;
          final categoryName =
              (category?['name'] as String? ?? '').toLowerCase();
          final equipment = ((row['equipment'] as List? ?? const [])
              .cast<Map<String, dynamic>>()
              .map((e) => e['name'] as String? ?? '')
              .where((e) => e.isNotEmpty)
              .join(', '));
          return WgerExerciseSuggestion(
            name: name,
            muscleGroup: _groupFor(categoryName),
            equipment: equipment,
          );
        })
        .where((item) => item.name.isNotEmpty)
        .toList();
    final seen = <String>{};
    return results
        .where((item) {
          return seen.add(item.name.trim().toLowerCase());
        })
        .take(20)
        .toList();
  }

  void dispose() => _client.close();

  MuscleGroup _groupFor(String name) {
    if (name.contains('chest')) return MuscleGroup.chest;
    if (name.contains('back')) return MuscleGroup.back;
    if (name.contains('leg')) return MuscleGroup.legs;
    if (name.contains('shoulder')) return MuscleGroup.shoulders;
    if (name.contains('arm') ||
        name.contains('bicep') ||
        name.contains('tricep')) return MuscleGroup.arms;
    if (name.contains('ab') || name.contains('core')) return MuscleGroup.core;
    if (name.contains('cardio')) return MuscleGroup.cardio;
    return MuscleGroup.other;
  }
}
