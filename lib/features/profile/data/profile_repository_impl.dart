import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/offline_data_store.dart';

import '../domain/profile.dart';
import '../domain/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final SupabaseClient _client;
  ProfileRepositoryImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String get _uid => _client.auth.currentUser!.id;

  @override
  Stream<UserProfile?> watchMyProfile() {
    // Filtering happens client-side (not .eq on the stream) because
    // realtime `.stream()` re-subscribes on filter identity changes;
    // watching the whole (RLS-scoped-to-self) table and mapping is the
    // documented-safe pattern for a single-row-per-user table.
    return OfflineDataStore.instance
        .watchRows(
      client: _client,
      table: 'profiles',
      queryKey: 'self',
      remote: _client.from('profiles').stream(primaryKey: ['id']),
    )
        .map((rows) {
      final mine = rows.where((r) => r['id'] == _uid);
      return mine.isEmpty ? null : UserProfile.fromMap(mine.first);
    });
  }

  @override
  Future<UserProfile?> getMyProfile() async {
    final rows = await OfflineDataStore.instance.fetchRows(
      client: _client,
      table: 'profiles',
      queryKey: 'self',
      fetch: () async {
        final row = await _client
            .from('profiles')
            .select()
            .eq('id', _uid)
            .maybeSingle();
        return row == null ? <Map<String, dynamic>>[] : [row];
      },
    );
    final mine = rows.where((row) => row['id'] == _uid);
    return mine.isEmpty ? null : UserProfile.fromMap(mine.first);
  }

  @override
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
  }) async {
    final map = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String()
    };
    if (displayName != null) map['display_name'] = displayName;
    if (invoiceName != null) map['invoice_name'] = invoiceName;
    if (defaultCurrency != null) map['default_currency'] = defaultCurrency;
    if (paymentInstructions != null) {
      map['payment_instructions'] = paymentInstructions;
    }
    if (professionalTitle != null) {
      map['professional_title'] = professionalTitle;
    }
    if (businessName != null) map['business_name'] = businessName;
    if (location != null) map['location'] = location;
    if (website != null) map['website'] = website;
    if (country != null) {
      final value = country.trim();
      map['country'] = value.isEmpty ? null : value;
    }
    await OfflineDataStore.instance.update(_client, 'profiles', _uid, map);
  }

  @override
  Future<void> setGymEnabled(bool enabled) {
    return OfflineDataStore.instance
        .update(_client, 'profiles', _uid, {'gym_enabled': enabled});
  }

  @override
  Future<void> completeOnboarding({
    required bool gymEnabled,
    required String displayName,
    required DateTime dateOfBirth,
    required String gender,
  }) {
    return OfflineDataStore.instance.update(_client, 'profiles', _uid, {
      'onboarding_done': true,
      'gym_enabled': gymEnabled,
      'display_name': displayName.trim(),
      'date_of_birth': dateOfBirth.toIso8601String().split('T').first,
      'gender': gender,
      'age_range': null,
    });
  }

  @override
  Future<String> uploadAvatar(Uint8List bytes, String fileExt) async {
    // Use a unique object for each replacement.  A stable public path plus
    // `upsert` can briefly serve a previous image through the CDN.
    final path =
        '$_uid/avatar-${DateTime.now().microsecondsSinceEpoch}.$fileExt';
    final previous = await getMyProfile();
    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$fileExt'),
        );
    final url = _client.storage.from('avatars').getPublicUrl(path);
    try {
      await _client.from('profiles').update({
        'avatar_url': url,
        'avatar_path': path,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', _uid);
    } catch (_) {
      // Existing production databases remain usable until the additive
      // avatar_path migration is deployed. They still receive the new image;
      // only precise old-file cleanup is deferred.
      try {
        await _client.from('profiles').update({
          'avatar_url': url,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', _uid);
      } catch (_) {
        await _client.storage.from('avatars').remove([path]);
        rethrow;
      }
    }

    // Storage cleanup must not make a successful replacement look failed.
    if (previous?.avatarPath?.isNotEmpty == true) {
      try {
        await _client.storage.from('avatars').remove([previous!.avatarPath!]);
      } catch (_) {
        // The profile already points to the new, valid image. A later cleanup
        // is harmless and better than rolling back a successful replacement.
      }
    }
    return url;
  }

  @override
  Future<void> removeAvatar({String? avatarPath}) async {
    try {
      await _client.from('profiles').update({
        'avatar_url': null,
        'avatar_path': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', _uid);
    } catch (_) {
      await _client.from('profiles').update({
        'avatar_url': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', _uid);
    }
    if (avatarPath?.isNotEmpty == true) {
      try {
        await _client.storage.from('avatars').remove([avatarPath!]);
      } catch (_) {
        // The user has already removed the image from their visible profile.
      }
    }
  }
}
