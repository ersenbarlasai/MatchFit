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

  Future<List<Map<String, dynamic>>> getNearbyEvents() async {
    // For MVP, we just fetch all open events
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
    final alreadyJoined = await isAlreadyJoined(eventId);
    if (alreadyJoined) throw Exception('You have already joined this event.');

    await _supabase.from('event_participants').insert({
      'event_id': eventId,
      'user_id': user.id,
      'status': 'joined'
    });
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
