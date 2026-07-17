class TaploeConfig {
  static const String supabaseUrl = 'https://gmpiygcnzlxllnablxmk.supabase.co';
  static const String supabaseRestUrl =
      'https://gmpiygcnzlxllnablxmk.supabase.co/rest/v1';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdtcGl5Z2Nuemx4bGxuYWJseG1rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2MTE1NjUsImV4cCI6MjA5OTE4NzU2NX0.3xYOvjvjuoNJW5DXemn0VaNUnC1IifluBjHVSa_uKBs';

  static const String publicBaseUrl = 'https://app.taploe.com';

  static String accessUrl(String token) => '$publicBaseUrl/a/$token';
  static String profileUrl(String slug) => '$publicBaseUrl/p/$slug';
}
