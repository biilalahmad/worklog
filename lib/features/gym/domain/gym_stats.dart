/// Aggregate gym stats for a period, computed server-side by the
/// get_gym_stats Postgres function — an efficient aggregate query
/// instead of downloading every set to sum on the client.
class GymStats {
  final int workoutsCompleted;
  final double totalVolume;
  final int totalSets;
  final Map<String, int> muscleGroups;

  const GymStats({
    this.workoutsCompleted = 0,
    this.totalVolume = 0,
    this.totalSets = 0,
    this.muscleGroups = const {},
  });

  factory GymStats.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const GymStats();
    final mg = (data['muscleGroups'] as Map<String, dynamic>?) ?? {};
    return GymStats(
      workoutsCompleted: (data['workoutsCompleted'] as num?)?.toInt() ?? 0,
      totalVolume: (data['totalVolume'] as num?)?.toDouble() ?? 0,
      totalSets: (data['totalSets'] as num?)?.toInt() ?? 0,
      muscleGroups: mg.map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }
}
