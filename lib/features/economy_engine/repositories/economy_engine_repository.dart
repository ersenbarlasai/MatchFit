import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class EconomyEngineRepository {
  final _supabase = Supabase.instance.client;

  /// Kullanıcıya MF Points ekler (pozitif) veya harcar (negatif).
  /// [amount] eklenecek/harcanacak miktar
  /// [source] Kaynak (Örn: 'check_in', 'app_open', 'reward_redemption')
  Future<void> addMFPoints(int amount, String source, {String description = ''}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.rpc('add_mf_points', params: {
        'p_user_id': user.id,
        'p_amount': amount,
        'p_source': source,
        'p_description': description,
      });

      debugPrint('[@EconomyEngine] $amount MF Points processed from $source');
    } catch (e) {
      debugPrint('[@EconomyEngine] Error adding MF Points: $e');
    }
  }

  /// Kullanıcının mevcut MF Points bakiyesini döner.
  Future<Map<String, dynamic>?> getUserMFBalance(String userId) async {
    try {
      final response = await _supabase
          .from('user_mf_balance')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
          
      return response;
    } catch (e) {
      debugPrint('[@EconomyEngine] Error fetching MF Balance: $e');
      return null;
    }
  }

  /// Kullanıcının MF Points hesap hareketlerini (ledger) döner.
  Future<List<Map<String, dynamic>>> getMFLedger() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase
          .from('mf_point_ledger')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(20);
          
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[@EconomyEngine] Error fetching MF ledger: $e');
      return [];
    }
  }
}
