import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class XPEngineRepository {
  final _supabase = Supabase.instance.client;

  /// Kullanıcıya XP ekler.
  /// Yeni parametrelerle birlikte detaylı hesaplama sağlar.
  Future<void> addUserXP(
    int amount,
    String source, {
    String qualityTier = 'B',
    String eventQuality = 'normal',
    bool isFirstEvent = false,
    int newPersonCount = 0,
    bool isNewBranch = false,
    int friendInviteCount = 0,
    bool isWeekend = false,
    bool isNoShow = false,
    String abuseStatus = 'clean',
    String? idempotencyKey,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.rpc('add_user_xp', params: {
        'p_user_id': user.id,
        'p_amount': amount,
        'p_source': source,
        'p_quality_tier': qualityTier,
        'p_event_quality': eventQuality,
        'p_is_first_event': isFirstEvent,
        'p_new_person_count': newPersonCount,
        'p_is_new_branch': isNewBranch,
        'p_friend_invite_count': friendInviteCount,
        'p_is_weekend': isWeekend,
        'p_is_no_show': isNoShow,
        'p_abuse_status': abuseStatus,
        if (idempotencyKey != null) 'p_idempotency_key': idempotencyKey,
      });

      debugPrint('[@XPEngine] Gained base $amount XP from $source (Tier: $qualityTier)');
    } catch (e) {
      debugPrint('[@XPEngine] Error adding XP: $e');
    }
  }

  /// Kullanıcının mevcut XP ve seviye bilgilerini döner.
  Future<Map<String, dynamic>?> getUserXPProfile(String userId) async {
    try {
      final response = await _supabase
          .from('user_xp')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
          
      return response;
    } catch (e) {
      debugPrint('[@XPEngine] Error fetching XP profile: $e');
      return null;
    }
  }

  /// Kullanıcının XP geçmişini döner.
  Future<List<Map<String, dynamic>>> getXPHistory() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase
          .from('xp_events')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(20);
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[@XPEngine] Error fetching XP history: $e');
      return [];
    }
  }
}
