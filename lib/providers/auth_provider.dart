import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as app_model;
import '../services/user_service.dart';

class AuthProvider with ChangeNotifier {
  final UserService _userService = UserService();
  final SupabaseClient supabase = Supabase.instance.client;

  app_model.User? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;

  app_model.User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _isAuthenticated;

  AuthProvider() {
    _initAuthListener();
    _loadCurrentUser();
  }

  void _initAuthListener() {
    supabase.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      _isLoading = true;
      notifyListeners();

      if (event == AuthChangeEvent.signedIn && session != null) {

        if (session.user.emailConfirmedAt != null) {
          final user = await _userService.getUser(session.user.id);
          _currentUser = user;
          _isAuthenticated = true;
        } else {

          debugPrint('[AuthProvider] Email not verified, signing out');
          await supabase.auth.signOut();
          _currentUser = null;
          _isAuthenticated = false;
        }
      } else if (event == AuthChangeEvent.signedOut) {
        _currentUser = null;
        _isAuthenticated = false;
      } else if (event == AuthChangeEvent.userUpdated && session != null) {

        if (session.user.emailConfirmedAt != null && !_isAuthenticated) {
          final user = await _userService.getUser(session.user.id);
          _currentUser = user;
          _isAuthenticated = true;
        }
      }

      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> _loadCurrentUser() async {
    final session = supabase.auth.currentSession;
    if (session?.user != null) {

      if (session!.user.emailConfirmedAt != null) {
        final user = await _userService.getUser(session.user.id);
        if (user != null) {
          _currentUser = user;
          _isAuthenticated = true;
          notifyListeners();
        }
      } else {

        debugPrint('[AuthProvider] Email not verified during _loadCurrentUser, signing out');
        await supabase.auth.signOut();
        _currentUser = null;
        _isAuthenticated = false;
        notifyListeners();
      }
    }
  }

  Future<bool> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required app_model.UserType userType,
    String? contactNumber,
    String? studentId,
    String? guardianName,
    String? guardianEmail,
    String? guardianContactNumber,
    String? studentInfo,
    String? teacherCode,
    int? grade,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final AuthResponse response = await supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user == null) {
        throw Exception('User creation failed. No user returned.');
      }
      final String uid = response.user!.id;
      debugPrint('[AuthProvider] User signed up with UID: $uid');
      await _userService.saveUser(
        id: uid,
        email: email,
        name: name,
        userType: userType,
        contactNumber: contactNumber,
        studentId: studentId,
        guardianName: guardianName,
        guardianEmail: guardianEmail,
        guardianContactNumber: guardianContactNumber,
        studentInfo: studentInfo,
        teacherCode: userType == app_model.UserType.teacher ? teacherCode : null,
        grade: userType == app_model.UserType.student ? grade : null,
      );

      debugPrint('[AuthProvider] User data inserted into "users" table.');
      debugPrint('[AuthProvider] Email confirmation required: ${response.user?.emailConfirmedAt == null}');

      await supabase.auth.signOut();

      debugPrint('[AuthProvider] User created successfully. Email verification required.');

      return true;

    } on PostgrestException catch (e) {
      _error = 'Database error: ${e.message}';
      debugPrint('[AuthProvider] PostgrestException: ${e.message}');
      return false;

    } on AuthException catch (e) {
      _error = 'Authentication error: ${e.message}';
      debugPrint('[AuthProvider] AuthException: ${e.message}');
      return false;

    } catch (e, stackTrace) {
      _error = 'Unexpected error: ${e.toString()}';
      debugPrint('[AuthProvider] Unexpected error: $e');
      debugPrint(stackTrace.toString());
      return false;

    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

    Future<void> refreshUserProfile() async {
    final session = supabase.auth.currentSession;
    if (session == null || session.user == null) return;

    final user = await _userService.getUser(session.user.id);
    if (user != null) {
      _currentUser = user;
      notifyListeners();
    }
  }

  Future<bool> signInWithEmailAndPassword(
      String email,
      String password,
      ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final AuthResponse response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Login failed: Supabase returned no user.');
      }

      if (response.user!.emailConfirmedAt == null) {
        await supabase.auth.signOut();
        _error = 'Please verify your email before signing in. Check your inbox for the verification link.';
        debugPrint('[AuthProvider] Login blocked: Email not verified');
        return false;
      }

      final String uid = response.user!.id;
      debugPrint('[AuthProvider] Signed in with UID: $uid');
      final user = await _userService.getUser(uid);
      if (user == null) {
        debugPrint('[AuthProvider] No matching record in "users" table for UID: $uid');
        await supabase.auth.signOut();

        _error = 'Access denied. Your account is not registered in the system.';
        return false;
      }
      _currentUser = user;
      _isAuthenticated = true;

      debugPrint('[AuthProvider] Login successful. User loaded: ${user.name}');
      return true;

    } on AuthException catch (e) {
      _error = 'Authentication error: ${e.message}';
      debugPrint('[AuthProvider] AuthException: ${e.message}');
      return false;

    } on PostgrestException catch (e) {
      _error = 'Database error: ${e.message}';
      debugPrint('[AuthProvider] PostgrestException: ${e.message}');
      return false;

    } catch (e, stackTrace) {
      _error = 'Unexpected error: ${e.toString()}';
      debugPrint('[AuthProvider] Unexpected error: $e');
      debugPrint(stackTrace.toString());
      return false;

    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setError(String message) {
    _error = message;
    notifyListeners();
  }

  Future<void> signOut() async {
    await supabase.auth.signOut(scope: SignOutScope.global);
    _currentUser = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<void> signOutAndRedirect(BuildContext context) async {
    try {
      debugPrint('[AuthProvider] Logging out user: ${_currentUser?.id}');
      await supabase.auth.signOut();

      debugPrint('[AuthProvider] Supabase session cleared.');

      _currentUser = null;
      _isAuthenticated = false;

      debugPrint('[AuthProvider] Local state cleared.');

      if (context.mounted) {
        debugPrint('[AuthProvider] Forcing navigation to WelcomeScreen...');
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/welcome',
              (route) => false,
        );
      }

      notifyListeners();

    } catch (e, stack) {
      debugPrint('[AuthProvider] Error during logout: $e');
      debugPrint(stack.toString());
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> resendVerificationEmail(String email) async {
    _error = null;
    notifyListeners();

    try {
      await supabase.auth.resend(
        type: OtpType.signup,
        email: email,
      );
      debugPrint('[AuthProvider] Verification email resent to: $email');
      return true;
    } on AuthException catch (e) {
      _error = 'Failed to resend verification email: ${e.message}';
      debugPrint('[AuthProvider] AuthException: ${e.message}');
      return false;
    } catch (e) {
      _error = 'Unexpected error: ${e.toString()}';
      debugPrint('[AuthProvider] Unexpected error: $e');
      return false;
    }
  }

  bool isEmailVerified() {
    final user = supabase.auth.currentUser;
    return user?.emailConfirmedAt != null;
  }
}
