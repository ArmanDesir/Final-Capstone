import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:offline_first_app/models/user.dart' as app_model;

class UserService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> saveUser({
    required String id,
    required String email,
    required String name,
    required app_model.UserType userType,
    String? contactNumber,
    String? studentId,
  }) async {
    await _supabase.from('users').insert({
      'id': id,
      'name': name,
      'email': email,
      'user_type': userType.name,
      'contact_number': contactNumber,
      'student_id': studentId,
    });
  }

  Future<app_model.User?> getUser(String id) async {
    final response = await _supabase
        .from('users')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return app_model.User.fromJson(response);
  }
}
