import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wingbase/services/pb_client.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  static const _tokenKey = "pb_auth_token";
  static const _recordKey = "pb_auth_record";

  // Helpers -----------------------------
  static bool _isPhoneNumber(String input) {
    final trimmed = input.trim();
    return trimmed.startsWith('+') || RegExp(r'^\d{7,15}$').hasMatch(trimmed);
  }

  static String _parseError(ClientException e) {
    print("PocketBase Error: ${e.response}"); // Debug print

    try {
      final data = e.response['data'];
      if (data is Map && data.isNotEmpty) {
        final first = data.values.first;
        if (first is Map && first['message'] != null) {
          String msg = first['message'];
          if (msg.contains('unique')) {
            return 'This email or phone number is already registered';
          }
          return msg;
        }
      }
      if (e.response['message'] != null) {
        String msg = e.response['message'];
        if (msg.contains('unique')) {
          return 'This email or phone number is already registered';
        }
        return msg;
      }
    } catch (_) {}
    return 'Something went wrong. Please try again';
  }

  static Future<String> _getEmailByPhone(String phone) async {
    try {
      final normalized = phone.replaceAll(' ', '');
      final result = await pb
          .collection('users')
          .getFirstListItem('phone = "$normalized"');
      return result.getStringValue('email');
    } catch (_) {
      throw AuthException('No account found with this phone number');
    }
  }

  // Getters -----------------------------
  static bool get isLoggedIn => pb.authStore.isValid;
  static RecordModel? get currentUser => pb.authStore.record;
  static String get currentUserId => pb.authStore.record?.id ?? '';

  // Save Session -------------------------
  static Future<void> saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, pb.authStore.token);
    await prefs.setString(
      _recordKey,
      jsonEncode(pb.authStore.record?.toJson()),
    );
  }

  // Restore Session -------------------------
  static Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final recordJson = prefs.getString(_recordKey);

    if (token == null || recordJson == null) {
      return false;
    }

    try {
      final recordData = jsonDecode(recordJson);
      pb.authStore.save(token, RecordModel.fromJson(recordData));

      await pb.collection('users').authRefresh();
      await saveSession();
      return true;
    } catch (_) {
      await clearSession();
      return false;
    }
  }

  // Clear Session -------------------------
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_recordKey);
    pb.authStore.clear();
  }

  // Register ---------------------------------
  static Future<RecordModel> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    File? avatar,
  }) async {
    print("Registering with: name=$name, email=$email, phone=$phone"); // Debug

    // Generate a unique username to satisfy the unique index
    final baseUsername = email
        .split('@')
        .first
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    final username = '${baseUsername}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final body = {
        'name': name,
        'username': username,
        'email': email.toLowerCase().trim(),
        'phone': phone.trim(),
        'password': password,
        'passwordConfirm': password,
        'about': "Hey I'm using WingBase",
      };

      RecordModel record;

      if (avatar != null) {
        print("With avatar");
        final mimeType = lookupMimeType(avatar.path) ?? 'image/jpeg';
        final files = [
          await http.MultipartFile.fromPath(
            'avatar',
            avatar.path,
            contentType: MediaType.parse(mimeType),
          ),
        ];
        record = await pb.collection('users').create(body: body, files: files);
      } else {
        print("Without avatar");
        record = await pb.collection('users').create(body: body);
      }

      print("User created, now authenticating...");
      await pb.collection('users').authWithPassword(email, password);
      await saveSession();

      return record;
    } on ClientException catch (e) {
      print("ClientException: ${e.response}"); // Debug
      throw AuthException(_parseError(e));
    } catch (e) {
      print("Exception: $e"); // Debug
      throw AuthException("Registration failed: $e");
    }
  }

  // Login ---------------------------------
  static Future<RecordModel> login({
    required String emailOrPhone,
    required String password,
  }) async {
    try {
      String email = emailOrPhone.trim();

      if (_isPhoneNumber(emailOrPhone)) {
        email = await _getEmailByPhone(emailOrPhone.trim());
      }

      final authData = await pb
          .collection('users')
          .authWithPassword(email, password);
      await saveSession();
      return authData.record;
    } catch (_) {
      throw AuthException('Login failed. Please try again.');
    }
  }

  // Logout --------------------------
  static Future<void> logout() async {
    await clearSession();
  }
}
