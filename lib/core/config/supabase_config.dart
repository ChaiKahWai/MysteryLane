import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl =
      'https://jhaozaxmpjqzogsbpebz.supabase.co';

  static const String supabaseAnonKey =
      'sb_publishable_h7QA8KVNbHZA_tSF5BSEyA_8mlq7Gv0';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}