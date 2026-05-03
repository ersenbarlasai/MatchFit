import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/repositories/auth_repository.dart';

final currentUserProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(authRepositoryProvider).currentUser;
  if (user == null) return null;

  final response = await Supabase.instance.client
      .from('profiles')
      .select('full_name, avatar_url, trust_score')
      .eq('id', user.id)
      .maybeSingle();

  final mergedProfile = {
    'full_name': response?['full_name'] ?? user.userMetadata?['full_name'] ?? 'U',
    'avatar_url': response?['avatar_url'] ?? user.userMetadata?['avatar_url'],
    'trust_score': response?['trust_score'] ?? 100,
  };

  return mergedProfile;
});
