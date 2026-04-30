import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider((ref) => AuthRepository());

final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

class AuthRepository {
  final _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;

  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<void> upsertProfile(Map<String, dynamic> profileData) async {
    final user = currentUser;
    if (user == null) throw Exception('No authenticated user found');
    
    // Ensure we are inserting/updating for the correct user ID
    profileData['id'] = user.id;
    profileData['email'] = user.email;
    
    await _supabase.from('profiles').upsert(profileData);
  }
}
