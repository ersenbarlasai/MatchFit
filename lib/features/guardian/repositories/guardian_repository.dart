import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final guardianRepositoryProvider = Provider((ref) => GuardianRepository());

class GuardianRepository {
  final _supabase = Supabase.instance.client;

  /// Checks if a new user has completed the 48-hour barrier
  /// "Yeni Üye Bariyeri: Hesabı yeni açılmış kullanıcılar ilk 48 saat etkinlik oluşturamaz."
  Future<bool> canCreateEvent(String userId) async {
    final response = await _supabase
        .from('profiles')
        .select('created_at')
        .eq('id', userId)
        .maybeSingle();

    if (response == null || response['created_at'] == null) return false;

    final createdAt = DateTime.parse(response['created_at']);
    final now = DateTime.now().toUtc();
    
    // If account is younger than 48 hours, they cannot create events
    if (now.difference(createdAt).inHours < 48) {
      return false; 
    }
    return true;
  }

  /// Scans text for security risks (e.g. IBAN or swearing)
  bool scanForRisks(String text) {
    final lowercaseText = text.toLowerCase();
    
    // Basic filter example (in a real app, use AI or advanced regex)
    final riskWords = ['iban', 'iban gönder', 'kredi kartı', 'numaramı kaydet'];
    
    for (var word in riskWords) {
      if (lowercaseText.contains(word)) {
        return true;
      }
    }
    return false;
  }

  /// Verifies if coordinates are a valid sports facility (Mock POI Check)
  Future<bool> validateEventLocation(double lat, double lng) async {
    if (lat == 0.0 && lng == 0.0) return false;
    return true;
  }

  /// Reads the user's privacy settings from Supabase
  Future<Map<String, dynamic>?> getPrivacySettings(String userId) async {
    return await _supabase
        .from('privacy_settings')
        .select('profile_visibility, hide_location_radius')
        .eq('user_id', userId)
        .maybeSingle();
  }

  /// Saves (upsert) the user's privacy settings to Supabase
  Future<void> savePrivacySettings({
    required String userId,
    required String profileVisibility,
    required int hideLocationRadius,
  }) async {
    await _supabase.from('privacy_settings').upsert({
      'user_id': userId,
      'profile_visibility': profileVisibility,
      'hide_location_radius': hideLocationRadius,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
  }
}
