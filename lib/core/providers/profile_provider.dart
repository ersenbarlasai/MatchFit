import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/repositories/auth_repository.dart';

final currentUserProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) return null;

  final response = await Supabase.instance.client
      .from('profiles')
      .select('full_name, first_name, last_name, avatar_url, cover_url, trust_score, city, district, phone, birth_date, role, is_coach')
      .eq('id', user.id)
      .maybeSingle();

  bool isCoach = response?['is_coach'] ?? false;
  
  // Fallback to directly checking coaches table
  if (!isCoach) {
    try {
      final coachResp = await Supabase.instance.client
          .from('coaches')
          .select('verification_level, is_active')
          .eq('user_id', user.id)
          .maybeSingle();
      if (coachResp != null) {
        final level = coachResp['verification_level'];
        final isActive = coachResp['is_active'];
        isCoach = (level != 'none' && level != 'pending' && isActive == true);
      }
    } catch (_) {}
  }

  final mergedProfile = {
    'role': response?['role'] ?? 'user',
    'is_coach': isCoach,
    'full_name': response?['full_name'] ?? user.userMetadata?['full_name'] ?? 'Misafir',
    'first_name': response?['first_name'] ?? '',
    'last_name': response?['last_name'] ?? '',
    'avatar_url': response?['avatar_url'] ?? user.userMetadata?['avatar_url'],
    'cover_url': response?['cover_url'],
    'trust_score': response?['trust_score'] ?? 0,
    'city': response?['city'] ?? '',
    'district': response?['district'] ?? '',
    'phone': response?['phone'] ?? '',
    'birth_date': response?['birth_date'],
  };

  return mergedProfile;
});

final userProfileProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, userId) async {
  final response = await Supabase.instance.client
      .from('profiles')
      .select('full_name, avatar_url, trust_score, bio, city, district, role, is_coach')
      .eq('id', userId)
      .maybeSingle();

  if (response != null) {
    final mutableResponse = Map<String, dynamic>.from(response);
    bool isCoach = mutableResponse['is_coach'] ?? false;
    
    // Fallback to directly checking coaches table
    if (!isCoach) {
      try {
        final coachResp = await Supabase.instance.client
            .from('coaches')
            .select('verification_level, is_active')
            .eq('user_id', userId)
            .maybeSingle();
        if (coachResp != null) {
          final level = coachResp['verification_level'];
          final isActive = coachResp['is_active'];
          isCoach = (level != 'none' && level != 'pending' && isActive == true);
          mutableResponse['is_coach'] = isCoach;
        }
      } catch (_) {}
    }
    return mutableResponse;
  }

  return response;
});
