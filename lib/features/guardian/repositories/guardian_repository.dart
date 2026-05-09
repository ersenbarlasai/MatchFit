import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matchfit/features/fraud_detection/repositories/fraud_detection_repository.dart';

final guardianRepositoryProvider = Provider((ref) {
  final fraudRepo = ref.read(fraudDetectionRepositoryProvider);
  return GuardianRepository(fraudRepo);
});

class GuardianRepository {
  final _supabase = Supabase.instance.client;
  final FraudDetectionRepository _fraudRepo;

  GuardianRepository(this._fraudRepo);

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

  Future<void> reportTextRisk({
    required String userId,
    required String text,
    String? eventId,
  }) async {
    if (!scanForRisks(text)) return;

    await _fraudRepo.logFraudSignal(
      userId: userId,
      sourceAgent: '@Guardian',
      signalType: 'risky_text_detected',
      severity: 'medium',
      confidence: 1.0,
      eventId: eventId,
      metadata: {'text': text},
      idempotencyKey:
          'guardian:text:$userId:${eventId ?? 'none'}:${text.hashCode}',
    );
  }

  /// Verifies if coordinates are a valid sports facility (Mock POI Check)
  Future<bool> validateEventLocation(double lat, double lng) async {
    if (lat == 0.0 && lng == 0.0) return false;
    return true;
  }

  Future<bool> validateEventLocationForUser({
    required String userId,
    required double lat,
    required double lng,
    String? eventId,
  }) async {
    final isValid = await validateEventLocation(lat, lng);
    if (!isValid) {
      await _fraudRepo.logFraudSignal(
        userId: userId,
        sourceAgent: '@Guardian',
        signalType: 'invalid_location',
        severity: 'high',
        confidence: 1.0,
        eventId: eventId,
        metadata: {'lat': lat, 'lng': lng},
        idempotencyKey:
            'guardian:location:$userId:${eventId ?? 'none'}:$lat:$lng',
      );
    }
    return isValid;
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
