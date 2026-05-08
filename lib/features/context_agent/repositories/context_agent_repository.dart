import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final contextAgentRepositoryProvider = Provider((ref) => ContextAgentRepository());

class ContextAgentRepository {
  final _supabase = Supabase.instance.client;

  /// Fetches the current context snapshot (city, weather, location info).
  /// This does NOT persist the snapshot in the database.
  Future<Map<String, dynamic>> getContextSnapshot({
    required String subjectType,
    String? subjectId,
    String? city,
  }) async {
    try {
      final response = await _supabase.rpc('get_context_snapshot', params: {
        'p_subject_type': subjectType,
        'p_subject_id': subjectId,
        'p_city': city,
      });
      return Map<String, dynamic>.from(response);
    } catch (e) {
      return {};
    }
  }

  /// Creates and persists a context snapshot for audit or cross-agent processing.
  Future<String?> createContextSnapshot({
    required String subjectType,
    required String subjectId,
    String? city,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _supabase.rpc('create_context_snapshot', params: {
        'p_subject_type': subjectType,
        'p_subject_id': subjectId,
        'p_city': city,
        'p_idempotency_key': idempotencyKey,
      });
      return response as String?;
    } catch (e) {
      return null;
    }
  }

  /// Updates city metadata (timezone, lat/lng, etc.).
  Future<void> upsertCityContext({
    required String city,
    String country = 'TR',
    String? timezone,
    double? latitude,
    double? longitude,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _supabase.rpc('upsert_city_context', params: {
        'p_city': city,
        'p_country': country,
        'p_timezone': timezone,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_metadata': metadata ?? {},
      });
    } catch (e) {
      // Log error internally if needed
    }
  }

  /// Updates weather cache for a city.
  Future<void> upsertWeatherCache({
    required String city,
    required String weatherCode,
    required double temperature,
    required double precipitationProbability,
    required double windSpeed,
    int expiresInMinutes = 60,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _supabase.rpc('upsert_weather_cache', params: {
        'p_city': city,
        'p_weather_code': weatherCode,
        'p_temperature': temperature,
        'p_precipitation_probability': precipitationProbability,
        'p_wind_speed': windSpeed,
        'p_expires_in_minutes': expiresInMinutes,
        'p_metadata': metadata ?? {},
      });
    } catch (e) {
      // Log error internally if needed
    }
  }
}
