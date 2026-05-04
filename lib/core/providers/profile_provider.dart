import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/repositories/auth_repository.dart';

final currentUserProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) return null;

  final response = await Supabase.instance.client
      .from('profiles')
      .select('full_name, first_name, last_name, avatar_url, cover_url, trust_score, city, district, phone, birth_date')
      .eq('id', user.id)
      .maybeSingle();

  final mergedProfile = {
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
