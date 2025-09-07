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
        final user = await _userService.getUser(session.user.id);
        _currentUser = user;
        _isAuthenticated = true;
      } else if (event == AuthChangeEvent.signedOut) {
        _currentUser = null;
        _isAuthenticated = false;
      }

      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> _loadCurrentUser() async {
    if (!_isAuthenticated) return;

    final session = supabase.auth.currentSession;
    if (session?.user != null) {
      final user = await _userService.getUser(session!.user.id);
      _currentUser = user;
      _isAuthenticated = true;
      notifyListeners();
    }
  }

  Future<bool> createUserWithEmailAndPassword(
      String email,
      String password,
      String name,
      app_model.UserType userType, {
        String? contactNumber,
        String? studentId,
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
        throw Exception('User creation failed.');
      }

      await _userService.saveUser(
        id: response.user!.id,
        email: email,
        name: name,
        userType: userType,
        contactNumber: contactNumber,
        studentId: studentId,
      );

      _currentUser = await _userService.getUser(response.user!.id);
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'An unexpected error occurred. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
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
        throw Exception('Sign in failed.');
      }

      final user = await _userService.getUser(response.user!.id);
      if (user == null) {
        throw Exception('User not found.');
      }

      _currentUser = user;
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'An unexpected error occurred. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
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
}
