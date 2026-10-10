import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository_impl.dart';
import '../../domain/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepositoryImpl());

final isSignedInProvider = StreamProvider<bool>((ref) {
  return ref.watch(authRepositoryProvider).watchIsSignedIn();
});

final authEventsProvider = StreamProvider<AuthEvent>((ref) {
  return ref.watch(authRepositoryProvider).watchAuthEvents();
});

/// Set while the user is inside the "choose a new password" flow after
/// tapping a reset link, so the router lets them stay on that screen.
final passwordRecoveryProvider = StateProvider<bool>((ref) => false);
