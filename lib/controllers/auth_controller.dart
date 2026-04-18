import 'package:supabase_flutter/supabase_flutter.dart';

class AuthController {
  final _supabase = Supabase.instance.client;

  // Fungsi Daftar Akun Baru (Manual ke tabel profiles)
  Future<void> signUpManual({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await _supabase.from('profiles').insert({
      'full_name': fullName,
      'email': email,
      'password': password, // Password terlihat di database (Plain Text)
      'role': 'user',        // Otomatis jadi user biasa
    });
  }

  // Fungsi Login Manual
  Future<Map<String, dynamic>?> signInManual({
    required String email,
    required String password,
  }) async {
    final response = await _supabase
        .from('profiles')
        .select()
        .eq('email', email)
        .eq('password', password)
        .maybeSingle();
    
    return response;
  }
}