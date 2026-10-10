class UserProfile {
  final String id;
  final String displayName;
  final String? invoiceName;
  final String? avatarUrl;

  /// Only set for an image the app uploaded to the `avatars` Storage bucket.
  /// External OAuth image URLs deliberately have no removable path.
  final String? avatarPath;
  final String defaultCurrency;
  final String? paymentInstructions;
  final String? professionalTitle;
  final String? businessName;
  final String? location;
  final String? website;
  final String? country;
  final String? ageRange;
  final String? gender;
  final DateTime? dateOfBirth;
  final bool gymEnabled;
  final bool onboardingDone;

  const UserProfile({
    required this.id,
    required this.displayName,
    this.invoiceName,
    this.avatarUrl,
    this.avatarPath,
    required this.defaultCurrency,
    this.paymentInstructions,
    this.professionalTitle,
    this.businessName,
    this.location,
    this.website,
    this.country,
    this.ageRange,
    this.gender,
    this.dateOfBirth,
    required this.gymEnabled,
    required this.onboardingDone,
  });

  /// The name that should print on invoices/reports: the dedicated
  /// "Your Name for Invoices" field if set, else the account display name.
  String get effectiveInvoiceName =>
      (invoiceName != null && invoiceName!.trim().isNotEmpty)
          ? invoiceName!
          : displayName;

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      displayName: (map['display_name'] as String?)?.trim().isNotEmpty == true
          ? map['display_name'] as String
          : 'WorkLog User',
      invoiceName: map['invoice_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      avatarPath: map['avatar_path'] as String?,
      defaultCurrency: (map['default_currency'] as String?) ?? 'PKR',
      paymentInstructions: map['payment_instructions'] as String?,
      professionalTitle: map['professional_title'] as String?,
      businessName: map['business_name'] as String?,
      location: map['location'] as String?,
      website: map['website'] as String?,
      country: map['country'] as String?,
      ageRange: map['age_range'] as String?,
      gender: map['gender'] as String?,
      dateOfBirth: DateTime.tryParse(map['date_of_birth'] as String? ?? ''),
      gymEnabled: (map['gym_enabled'] as bool?) ?? false,
      onboardingDone: (map['onboarding_done'] as bool?) ?? false,
    );
  }

  UserProfile copyWith({
    String? displayName,
    String? invoiceName,
    String? avatarUrl,
    String? avatarPath,
    String? defaultCurrency,
    String? paymentInstructions,
    bool? gymEnabled,
    bool? onboardingDone,
    String? professionalTitle,
    String? businessName,
    String? location,
    String? website,
    String? country,
    String? ageRange,
    String? gender,
    DateTime? dateOfBirth,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      invoiceName: invoiceName ?? this.invoiceName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarPath: avatarPath ?? this.avatarPath,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      paymentInstructions: paymentInstructions ?? this.paymentInstructions,
      gymEnabled: gymEnabled ?? this.gymEnabled,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      professionalTitle: professionalTitle ?? this.professionalTitle,
      businessName: businessName ?? this.businessName,
      location: location ?? this.location,
      website: website ?? this.website,
      country: country ?? this.country,
      ageRange: ageRange ?? this.ageRange,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    );
  }

  int? ageAt([DateTime? onDate]) {
    final birthDate = dateOfBirth;
    if (birthDate == null) return null;
    final today = onDate ?? DateTime.now();
    var years = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      years--;
    }
    return years;
  }
}
