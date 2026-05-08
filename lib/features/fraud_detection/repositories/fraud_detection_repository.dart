import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final fraudDetectionRepositoryProvider = Provider((ref) => FraudDetectionRepository());

class FraudDetectionRepository {
  final _supabase = Supabase.instance.client;

  /// Logs a fraud signal from any agent.
  /// sourceAgent: e.g. '@Guardian'
  /// signalType: e.g. 'bad_word', 'location_spoof'
  Future<String?> logFraudSignal({
    required String userId,
    required String sourceAgent,
    required String signalType,
    String severity = 'low',
    double confidence = 1.0,
    String? eventId,
    Map<String, dynamic>? metadata,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _supabase.rpc('log_fraud_signal', params: {
        'p_user_id': userId,
        'p_source_agent': sourceAgent,
        'p_signal_type': signalType,
        'p_severity': severity,
        'p_confidence': confidence,
        'p_event_id': eventId,
        'p_metadata': metadata ?? {},
        'p_idempotency_key': idempotencyKey,
      });
      return response as String?;
    } catch (e) {
      // In a real app, log error but don't break the user flow as fraud detection is often async/secondary
      return null;
    }
  }

  /// Fetches a high-level risk summary for a user.
  /// Used by @Referee, @RankingEngine, etc.
  Future<Map<String, dynamic>> getUserRiskSummary(String userId) async {
    try {
      final response = await _supabase.rpc('get_user_risk_summary', params: {
        'p_user_id': userId,
      });
      return Map<String, dynamic>.from(response);
    } catch (e) {
      return {
        'user_id': userId,
        'score': 0,
        'risk_level': 'clear',
        'is_blocked': false
      };
    }
  }
}
