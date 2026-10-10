import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/profile_repository_impl.dart';
import '../../domain/profile.dart';
import '../../domain/profile_repository.dart';

final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => ProfileRepositoryImpl());

/// Live profile row for the signed-in user. Streams so a Gym-toggle
/// flip (or a profile edit made on another device) rebuilds instantly
/// everywhere this is watched — no manual refresh.
final profileProvider = StreamProvider<UserProfile?>((ref) {
  // Re-subscribe whenever sign-in state flips, otherwise a fresh login
  // after a sign-out would keep streaming the previous (empty) query.
  ref.watch(isSignedInProvider);
  final signedIn = ref.read(authRepositoryProvider).isSignedIn;
  if (!signedIn) return Stream.value(null);
  return ref.watch(profileRepositoryProvider).watchMyProfile();
});

/// The offline profile stream can emit an old cached onboarding flag before
/// Supabase sends the current row. Keep routing decisions on the live server
/// stream so returning users are never briefly shown first-run setup.
final onboardingDoneProvider = StreamProvider<bool?>((ref) {
  ref.watch(isSignedInProvider);
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return Stream.value(null);
  return client.from('profiles').stream(primaryKey: ['id']).map((rows) {
    for (final row in rows) {
      if (row['id'] == userId) return row['onboarding_done'] as bool? ?? false;
    }
    return null;
  });
});

class CurrencyDisplayOverride {
  const CurrencyDisplayOverride({required this.userId, required this.currency});
  final String userId;
  final String currency;
}

/// Lets currency changes render immediately while the profile update is saved.
final currencyDisplayOverrideProvider =
    StateProvider<CurrencyDisplayOverride?>((ref) => null);

/// Drives the bottom nav: whether Gym is a tab right now.
final gymEnabledProvider = Provider<bool>((ref) {
  return ref.watch(profileProvider).valueOrNull?.gymEnabled ?? false;
});

final defaultCurrencyProvider = Provider<String>((ref) {
  final profile = ref.watch(profileProvider).valueOrNull;
  final userId = profile?.id ?? ref.read(authRepositoryProvider).currentUserId;
  final override = ref.watch(currencyDisplayOverrideProvider);
  if (override != null && override.userId == userId) return override.currency;
  return profile?.defaultCurrency ?? 'PKR';
});

/// Name to print on invoices/reports — falls back to the account email
/// while the profile row is still loading, then to a generic label.
final displayNameProvider = Provider<AsyncValue<String>>((ref) {
  final profileAsync = ref.watch(profileProvider);
  return profileAsync.whenData((p) {
    if (p != null) return p.effectiveInvoiceName;
    return ref.read(authRepositoryProvider).currentUserEmail ?? 'WorkLog User';
  });
});
