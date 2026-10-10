import 'package:flutter_test/flutter_test.dart';
import 'package:worklog/features/profile/domain/profile.dart';

void main() {
  test('professional profile details load from and copy profile data', () {
    final profile = UserProfile.fromMap({
      'id': 'user-1',
      'display_name': 'Bilal Ahmad',
      'default_currency': 'PKR',
      'professional_title': 'Video Editor',
      'business_name': 'Bilal Studio',
      'location': 'Lahore, Pakistan',
      'website': 'https://example.com',
    });

    expect(profile.professionalTitle, 'Video Editor');
    expect(profile.businessName, 'Bilal Studio');
    expect(profile.location, 'Lahore, Pakistan');
    expect(profile.website, 'https://example.com');
  });

  test('age is derived from date of birth and advances on the birthday', () {
    final profile = UserProfile.fromMap({
      'id': 'user-2',
      'display_name': 'Amina',
      'default_currency': 'PKR',
      'date_of_birth': '2000-10-11',
      'gender': 'woman',
    });

    expect(profile.ageAt(DateTime(2026, 10, 10)), 25);
    expect(profile.ageAt(DateTime(2026, 10, 11)), 26);
    expect(profile.gender, 'woman');
  });
}
