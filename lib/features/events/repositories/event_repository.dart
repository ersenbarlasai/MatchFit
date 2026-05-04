import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../utils/event_time_utils.dart';

final eventRepositoryProvider = Provider((ref) => EventRepository());

class EventSignalNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void emit() => state++;
}

final eventChangeProvider = NotifierProvider<EventSignalNotifier, int>(
  EventSignalNotifier.new,
);

class EventRepository {
  final _supabase = Supabase.instance.client;

  Future<void> createEvent(Map<String, dynamic> eventData) async {
    await _supabase.from('events').insert(eventData);
  }

  Future<void> updateEvent(
    String eventId,
    Map<String, dynamic> eventData,
  ) async {
    await _supabase.from('events').update(eventData).eq('id', eventId);
  }

  Future<void> deleteEvent(String eventId) async {
    await _supabase.from('events').delete().eq('id', eventId);
  }

  Future<Map<String, dynamic>?> getEventDetails(String eventId) async {
    final response = await _supabase
        .from('events')
        .select(
          '*, sports(name, category), profiles(full_name, trust_score, avatar_url)',
        )
        .eq('id', eventId)
        .maybeSingle();
    return response;
  }

  Future<List<Map<String, dynamic>>> getNearbyEvents({
    double? lat,
    double? lng,
    double? radius,
  }) async {
    List<Map<String, dynamic>> rawEvents = [];

    if (lat != null && lng != null && radius != null) {
      final response = await _supabase.rpc(
        'get_nearby_events',
        params: {'user_lat': lat, 'user_lng': lng, 'radius_meters': radius},
      );
      // RPC returns different structure, we need to map it back to what UI expects
      rawEvents = (response as List)
          .map(
            (e) => Map<String, dynamic>.from({
              ...e,
              'sports': {'name': e['sport_name'], 'category': e['category']},
              'profiles': {
                'full_name': e['host_name'],
                'avatar_url': e['host_avatar'],
              },
            }),
          )
          .toList();
    } else {
      // Fallback or 'Any' selection: fetch ALL open events
      final response = await _supabase
          .from('events')
          .select(
            '*, sports(name, category), profiles(full_name, trust_score, avatar_url)',
          )
          .eq('status', 'open')
          .order('event_date', ascending: true);
      rawEvents = List<Map<String, dynamic>>.from(response);
    }

    return rawEvents.where(EventTimeUtils.isUpcoming).toList();
  }

  Future<List<String>> _getBlockedIds() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return [];

    final response = await _supabase
        .from('user_relationships')
        .select('sender_id, receiver_id')
        .eq('status', 'blocked')
        .or('sender_id.eq.$myId,receiver_id.eq.$myId');

    return List<Map<String, dynamic>>.from(response).map((r) {
      return (r['sender_id'] == myId ? r['receiver_id'] : r['sender_id'])
          as String;
    }).toList();
  }

  Future<void> joinEvent(String eventId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Kullanıcı girişi yapılmamış.');

    // 1. Fetch event info first (needed for notification and guards)
    final eventData = await _supabase
        .from('events')
        .select('host_id')
        .eq('id', eventId)
        .maybeSingle();

    if (eventData == null) throw Exception('Etkinlik bulunamadı.');
    final hostId = eventData['host_id'] as String;

    // 2. Block guard
    final blockedIds = await _getBlockedIds();
    if (blockedIds.contains(hostId)) {
      throw Exception('Bu etkinliğe katılamazsınız.');
    }

    // 3. Check existing participation
    final data = await getParticipantData(eventId);
    bool isUpdate = false;

    if (data != null) {
      final status = data['status'];
      final rejectionCount = data['rejection_count'] ?? 0;
      final lastRejectedAtStr = data['last_rejected_at'];

      if (status == 'pending')
        throw Exception('Katılım isteğiniz onay bekliyor.');
      if (status == 'joined') throw Exception('Bu etkinliğe zaten katıldınız.');

      if (status == 'rejected') {
        if (rejectionCount >= 2) {
          throw Exception(
            'Bu etkinliğe katılma isteğiniz daha önce 2 kez reddedildi. Bir daha istek gönderemezsiniz.',
          );
        }

        if (lastRejectedAtStr != null) {
          final lastRejectedAt = DateTime.parse(lastRejectedAtStr);
          final now = DateTime.now();
          final diff = now.difference(lastRejectedAt);
          if (diff.inHours < 2) {
            final remainingMinutes = 120 - diff.inMinutes;
            throw Exception(
              'İsteğiniz reddedildi. Yeniden istek gönderebilmek için $remainingMinutes dakika beklemeniz gerekiyor.',
            );
          }
        }
        isUpdate = true;
      }
    }

    // 4. Perform Join
    if (isUpdate) {
      await _supabase
          .from('event_participants')
          .update({'status': 'pending'})
          .eq('event_id', eventId)
          .eq('user_id', user.id);
    } else {
      await _supabase.from('event_participants').insert({
        'event_id': eventId,
        'user_id': user.id,
        'status': 'pending',
      });
    }
    // NOTE: Notification to host for first time is handled automatically by the DB trigger
    // `on_join_request` (SECURITY DEFINER). Re-join notifications are handled by
    // `on_join_request_update` when status changes from rejected to pending.
  }

  Future<String?> getParticipantStatus(String eventId) async {
    final data = await getParticipantData(eventId);
    return data?['status'] as String?;
  }

  Stream<String?> watchParticipantStatus(String eventId) {
    final user = _supabase.auth.currentUser;
    if (user == null) return Stream.value(null);

    return _supabase
        .from('event_participants')
        .stream(primaryKey: ['id'])
        .eq('event_id', eventId)
        .map((data) {
          final filtered = data
              .where((row) => row['user_id'] == user.id)
              .toList();
          return filtered.isEmpty ? null : filtered.first['status'] as String?;
        });
  }

  Future<Map<String, dynamic>?> getParticipantData(String eventId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      return await _supabase
          .from('event_participants')
          .select('status, rejection_count, last_rejected_at')
          .eq('event_id', eventId)
          .eq('user_id', user.id)
          .maybeSingle();
    } catch (e) {
      // Eğer yeni kolonlar (rejection_count vb.) henüz eklenmemişse hata alabiliriz.
      // Bu durumda sadece status kolonunu çekerek sistemi ayakta tutuyoruz.
      final fallback = await _supabase
          .from('event_participants')
          .select('status')
          .eq('event_id', eventId)
          .eq('user_id', user.id)
          .maybeSingle();
      return fallback;
    }
  }

  Future<List<Map<String, dynamic>>> getJoinRequests(String eventId) async {
    final response = await _supabase
        .from('event_participants')
        .select('*, profiles(full_name, avatar_url, trust_score)')
        .eq('event_id', eventId)
        .eq('status', 'pending');
    return List<Map<String, dynamic>>.from(response);
  }

  Stream<List<Map<String, dynamic>>> watchJoinRequests(String eventId) {
    return _supabase
        .from('event_participants')
        .stream(primaryKey: ['id'])
        .eq('event_id', eventId)
        .asyncMap((data) async {
          final pending = data
              .where((row) => row['status'] == 'pending')
              .toList();
          if (pending.isEmpty) return [];

          final userIds = pending.map((p) => p['user_id'] as String).toList();

          try {
            // Fetch all profiles in one go for performance
            final profilesData = await _supabase
                .from('profiles')
                .select('id, full_name, avatar_url, trust_score')
                .inFilter('id', userIds);

            final profileMap = {
              for (var p in profilesData) p['id'] as String: p,
            };

            return pending
                .map(
                  (item) => {...item, 'profiles': profileMap[item['user_id']]},
                )
                .toList();
          } catch (e) {
            debugPrint('Error enriching join requests: $e');
            return pending; // Return without profiles if enrichment fails
          }
        });
  }

  Future<void> updateJoinStatus(
    String eventId,
    String userId,
    String newStatus,
  ) async {
    final updates = <String, dynamic>{'status': newStatus};

    if (newStatus == 'rejected') {
      try {
        final currentData = await _supabase
            .from('event_participants')
            .select('rejection_count')
            .eq('event_id', eventId)
            .eq('user_id', userId)
            .maybeSingle();

        final currentCount = currentData?['rejection_count'] ?? 0;
        updates['rejection_count'] = currentCount + 1;
        updates['last_rejected_at'] = DateTime.now().toUtc().toIso8601String();
      } catch (e) {
        // Migration henüz çalıştırılmamış, kolonlar yok.
        // Sadece status güncellenecek şekilde devam et.
        debugPrint('rejection_count check failed (migration not run): $e');
      }
    }

    try {
      await _supabase
          .from('event_participants')
          .update(updates)
          .eq('event_id', eventId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint(
        'Update with extra columns failed, falling back to status only: $e',
      );
      await _supabase
          .from('event_participants')
          .update({'status': newStatus})
          .eq('event_id', eventId)
          .eq('user_id', userId);
    }
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
