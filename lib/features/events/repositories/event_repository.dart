import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final eventRepositoryProvider = Provider((ref) => EventRepository());

class EventRepository {
  final _supabase = Supabase.instance.client;

  Future<void> createEvent(Map<String, dynamic> eventData) async {
    await _supabase.from('events').insert(eventData);
  }

  Future<void> updateEvent(String eventId, Map<String, dynamic> eventData) async {
    await _supabase.from('events').update(eventData).eq('id', eventId);
  }

  Future<void> deleteEvent(String eventId) async {
    await _supabase.from('events').delete().eq('id', eventId);
  }

  Future<List<Map<String, dynamic>>> getNearbyEvents({double? lat, double? lng, double radius = 20000}) async {
    if (lat != null && lng != null) {
      final response = await _supabase.rpc('get_nearby_events', params: {
        'user_lat': lat,
        'user_lng': lng,
        'radius_meters': radius,
      });
      // RPC returns different structure, we need to map it back to what UI expects
      return (response as List).map((e) => Map<String, dynamic>.from({
        ...e,
        'sports': {'name': e['sport_name']},
        'profiles': {
          'full_name': e['host_name'],
          'avatar_url': e['host_avatar'],
        }
      })).toList();
    }

    // Fallback if no location
    final response = await _supabase
        .from('events')
        .select('*, sports(name), profiles(full_name, trust_score, avatar_url)')
        .eq('status', 'open')
        .order('event_date', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> joinEvent(String eventId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Guard: check before inserting to avoid duplicate key errors
    final status = await getParticipantStatus(eventId);
    if (status != null) {
      if (status == 'pending') throw Exception('Your request is already pending approval.');
      if (status == 'joined') throw Exception('You have already joined this event.');
      if (status == 'rejected') throw Exception('Your request to join this event was rejected.');
    }

    await _supabase.from('event_participants').insert({
      'event_id': eventId,
      'user_id': user.id,
      'status': 'pending' // Default to pending for approval system
    });
  }

  Future<String?> getParticipantStatus(String eventId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('event_participants')
        .select('status')
        .eq('event_id', eventId)
        .eq('user_id', user.id)
        .maybeSingle();

    return response?['status'] as String?;
  }

  Future<List<Map<String, dynamic>>> getJoinRequests(String eventId) async {
    final response = await _supabase
        .from('event_participants')
        .select('*, profiles(full_name, avatar_url, trust_score)')
        .eq('event_id', eventId)
        .eq('status', 'pending');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updateJoinStatus(String eventId, String userId, String newStatus) async {
    await _supabase
        .from('event_participants')
        .update({'status': newStatus})
        .eq('event_id', eventId)
        .eq('user_id', userId);
  }

  /// Checks if the current user is already a participant of the event
  Future<bool> isAlreadyJoined(String eventId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    final response = await _supabase
        .from('event_participants')
        .select('id')
        .eq('event_id', eventId)
        .eq('user_id', user.id)
        .maybeSingle();

    return response != null;
  }
}
