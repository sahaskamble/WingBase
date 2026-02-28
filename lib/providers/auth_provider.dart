import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:wingbase/services/auth_service.dart';
import 'package:wingbase/services/pb_client.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  RecordModel? _user;
  String? _error;
  bool _loading = false;

  AuthStatus get status => _status;
  RecordModel? get user => _user;
  String? get error => _error;
  bool get loading => _loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() {
    // Live auth updates from Pocketbase
    pb.authStore.onChange.listen((_) {
      _user = AuthService.currentUser;
      _status = AuthService.isLoggedIn
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated;
      notifyListeners();
    });
  }

  //-------------------------------------
  // Auto Login
  //-------------------------------------
  Future<void> tryAutoLogin() async {
    _loading = true;
    notifyListeners();

    final success = await AuthService.restoreSession();

    if (success) {
      _user = AuthService.currentUser;
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }

    _loading = false;
    notifyListeners();
  }

  //-------------------------------------
  // Login
  //-------------------------------------
  Future<bool> login({
    required String emailOrPhone,
    required String password,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await AuthService.login(
        emailOrPhone: emailOrPhone,
        password: password,
      );
      _status = AuthStatus.authenticated;
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  //-------------------------------------
  // Register
  //-------------------------------------
  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    File? avatar,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await AuthService.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
        avatar: avatar,
      );
      _status = AuthStatus.authenticated;
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  //-------------------------------------
  // Logout
  //-------------------------------------
  Future<void> logout() async {
    await AuthService.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    _error = null;
    notifyListeners();
  }

  //─────────────────────────────
  //Helpers
  //─────────────────────────────
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
