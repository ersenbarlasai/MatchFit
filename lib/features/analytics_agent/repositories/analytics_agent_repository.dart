import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final analyticsAgentRepositoryProvider = Provider((ref) => AnalyticsAgentRepository());

class AnalyticsAgentRepository {
  final _supabase = Supabase.instance.client;

  /// Logs a telemetry event to the centralized analytics system.
  Future<String?> logAnalyticsEvent({
    required String agentName,
    required String eventType,
    String? userId,
    String? eventId,
    String? subjectType,
    String? subjectId,
    String severity = 'info',
    Map<String, dynamic>? metrics,
    Map<String, dynamic>? metadata,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _supabase.rpc('log_analytics_event', params: {
        'p_agent_name': agentName,
        'p_event_type': eventType,
        'p_user_id': userId,
        'p_event_id': eventId,
        'p_subject_type': subjectType,
        'p_subject_id': subjectId,
        'p_severity': severity,
        'p_metrics': metrics ?? {},
        'p_metadata': metadata ?? {},
        'p_idempotency_key': idempotencyKey,
      });
      return response as String?;
    } catch (e) {
      return null;
    }
  }

  /// Fetches a summary of agent health for a specific date.
  Future<List<Map<String, dynamic>>> getAgentHealthSummary({DateTime? date}) async {
    try {
      final targetDate = date ?? DateTime.now();
      final formattedDate = "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";
      
      final response = await _supabase.rpc('get_agent_health_summary', params: {
        'p_snapshot_date': formattedDate,
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Triggers a daily health aggregation (Admin only usage ideally).
  Future<void> buildDailyHealth({DateTime? date}) async {
    try {
      final targetDate = date ?? DateTime.now();
      final formattedDate = "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";

      await _supabase.rpc('build_daily_agent_health', params: {
        'p_snapshot_date': formattedDate,
      });
    } catch (e) {
      // Log error internally if needed
    }
  }
}
