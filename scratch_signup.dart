
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('Creating sponsor account...');
  
  // Initialize Supabase (Minimal for CLI)
  final supabase = SupabaseClient(
    'https://dropugfwzqequavuonvm.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRyb3B1Z2Z3enFlcXVhdnVvbnZtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc1NTQzODEsImV4cCI6MjA5MzEzMDM4MX0.LFaJcRLwiY_iFCG0mYryYxRSdNa-59l6PZ2cIdQAyVw',
  );

  try {
    final response = await supabase.auth.signUp(
      email: 'sponsor@matchfit.com',
      password: '12345678',
    );
    
    if (response.user != null) {
      print('SUCCESS: User created with ID: ${response.user!.id}');
      print('NOTE: Please run the following SQL in Supabase Dashboard to set the role:');
      print('UPDATE profiles SET role = \'partner\' WHERE id = \'${response.user!.id}\';');
    } else {
      print('ERROR: Response user is null');
    }
  } catch (e) {
    if (e.toString().contains('already registered')) {
      print('INFO: User already exists.');
    } else {
      print('ERROR: $e');
    }
  }
}
