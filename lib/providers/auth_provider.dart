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
  }

  /// Listens for authentication state changes from Supabase.
  /// This automatically loads the user's profile when they sign in
  /// and clears the user when they sign out.
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

  /// Creates a new user account using Supabase Auth.
  /// After successful creation, it saves the user's profile to a separate table.
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

      // Supabase's auth service does not store extra user data.
      // We must insert the user profile into our separate 'users' table.
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
    } catch (e) {
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

  /// Signs in a user with email and password using Supabase Auth.
  Future<bool> signInWithEmailAndPassword(
      String email,
      String password,
      app_model.UserType userType,
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
      if (user == null || user.userType != userType) {
        throw Exception('Invalid credentials or user type.');
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
    } catch (e) {
      _error = 'An unexpected error occurred. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Signs the current user out using Supabase Auth.
  Future<void> signOut() async {
    await supabase.auth.signOut();
    _currentUser = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  /// Clears any stored error message.
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
