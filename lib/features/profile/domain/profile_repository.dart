import 'dart:typed_data';

import 'profile.dart';

abstract class ProfileRepository {
  Stream<UserProfile?> watchMyProfile();
  Future<UserProfile?> getMyProfile();

  Future<void> updateProfile({
    String? displayName,
    String? invoiceName,
    String? defaultCurrency,
    String? paymentInstructions,
    String? professionalTitle,
    String? businessName,
    String? location,
    String? website,
    String? country,
  });

  /// Turns Gym & Diet tracking on/off — drives the bottom-nav rebuild.
  Future<void> setGymEnabled(bool enabled);

  /// Marks the one-time onboarding flow as complete.
  Future<void> completeOnboarding({
    required bool gymEnabled,
    required String displayName,
    required DateTime dateOfBirth,
    required String gender,
  });

  Future<String> uploadAvatar(Uint8List bytes, String fileExt);
  Future<void> removeAvatar({String? avatarPath});
}
