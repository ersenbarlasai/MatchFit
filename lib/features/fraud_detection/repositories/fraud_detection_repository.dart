import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final fraudDetectionRepositoryProvider =
    Provider<FraudDetectionRepository>((ref) {
  return FraudDetectionRepository(Supabase.instance.client);
});

class FraudDetectionRepository {
  final SupabaseClient _supabase;

  FraudDetectionRepository(this._supabase);

  Future<void> logFraudSignal({
    required String userId,
    required String sourceAgent,
    required String signalType,
    String severity = 'medium',
    double confidence = 1.0,
    String? eventId,
    Map<String, dynamic>? metadata,
    String? idempotencyKey,
  }) async {
    try {
      await _supabase.rpc(
        'log_fraud_signal',
        params: {
          'p_user_id': userId,
          'p_source_agent': sourceAgent,
          'p_signal_type': signalType,
          'p_severity': severity,
          'p_confidence': confidence,
          'p_event_id': eventId,
          'p_metadata': metadata ?? <String, dynamic>{},
          'p_idempotency_key': idempotencyKey,
        },
      );
    } catch (e) {
      debugPrint('[@FraudDetection] Failed to log fraud signal: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserRiskSummary(String userId) async {
    try {
      final response = await _supabase.rpc(
        'get_user_risk_summary',
        params: {'p_user_id': userId},
      );

      if (response is Map<String, dynamic>) return response;
      return null;
    } catch (e) {
      debugPrint('[@FraudDetection] Failed to fetch risk summary: $e');
      return null;
    }
  }
}
