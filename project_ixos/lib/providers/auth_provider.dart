import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../models/user.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final _storage = const FlutterSecureStorage();
  User? _currentUser;
  bool _isLoading = false;
  bool _rememberMe = true; // Default to true

  AuthProvider(this._authService);

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get rememberMe => _rememberMe;

  set rememberMe(bool value) {
    _rememberMe = value;
    notifyListeners();
  }

  Future<void> checkAuth() async {
    _isLoading = true;
    notifyListeners();

    final rememberStr = await _storage.read(key: 'rememberMe');
    _rememberMe = rememberStr == 'true';

    if (!_rememberMe) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    final userId = await _storage.read(key: 'userId');
    final token = await _storage.read(key: 'accessToken');

    if (userId != null && token != null) {
      try {
        final response = await http.get(
          Uri.parse('${_authService.baseUrl}/api/v1/me/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          _currentUser = User.fromJson(jsonDecode(response.body));
        }
      } catch (e) {
        print('CheckAuth error: $e');
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String identifier, String password) async {
    _isLoading = true;
    notifyListeners();

    final result = await _authService.login(identifier, password);
    
    if (result != null) {
      await _storage.write(key: 'rememberMe', value: _rememberMe.toString());

      if (result['user'] != null) {
        _currentUser = User.fromJson(result['user']);
      } else {
        // If the API doesn't return a user object on login, create a skeleton user
        // so the app still considers itself authenticated.
        _currentUser = User(
          id: result['userId'] ?? 'unknown',
          username: identifier,
          email: identifier,
          displayName: 'User',
        );
      }
      _isLoading = false;
      notifyListeners();
      return true;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    _isLoading = true;
    notifyListeners();

    final result = await _authService.register(
      username: username,
      email: email,
      password: password,
      displayName: displayName,
    );

    if (result != null) {
      if (result['user'] != null) {
        _currentUser = User.fromJson(result['user']);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  void logout() {
    _authService.logout();
    _currentUser = null;
    notifyListeners();
  }
}
