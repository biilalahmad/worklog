import 'package:flutter_riverpod/flutter_riverpod.dart';

const firstLaunchPreferenceKey = 'worklog.first_launch_complete';

/// Whether the one-time product introduction has been completed on this install.
final firstLaunchCompleteProvider = StateProvider<bool>((ref) => false);
