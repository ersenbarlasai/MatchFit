class AppConstants {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://dropugfwzqequavuonvm.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRyb3B1Z2Z3enFlcXVhdnVvbnZtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc1NTQzODEsImV4cCI6MjA5MzEzMDM4MX0.LFaJcRLwiY_iFCG0mYryYxRSdNa-59l6PZ2cIdQAyVw',
  );
}
