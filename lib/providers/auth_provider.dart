import 'package:flutter/foundation.dart';

import '../data/models/users.dart';
import '../data/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService();

  final AuthService _authService;

  bool _loading = false;
  String? _error;
  User? _user;

  bool allowDownloads = true;
  bool showRatings = true;
  bool challengeReminders = false;

  bool get loading => _loading;
  String? get error => _error;
  User? get user => _user;

  void setAllowDownloads(bool v) {
    allowDownloads = v;
    notifyListeners();
  }

  void setShowRatings(bool v) {
    showRatings = v;
    notifyListeners();
  }

  void setChallengeReminders(bool v) {
    challengeReminders = v;
    notifyListeners();
  }

  int? get userId {
    final raw = _user?.id;
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  Future<void> init() async {
    _setLoading(true);
    try {
      final hasToken = await _authService.hasToken();
      if (!hasToken) {
        _user = null;
        _error = null;
        return;
      }

      final me = await _authService.me();
      _user = me;
      _error = null;
    } catch (_) {
      await _authService.logout();
      _user = null;
      _error = null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    try {
      final res = await _authService.login(email: email, password: password);

      // AuthService already saved the token into TokenStorage
      _user = res.user;
      _error = null;

      return true;
    } catch (e) {
      _user = null;
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// STEP 1: send code (does NOT log user in)
  Future<bool> requestRegister(
      String email, String password, String confirmPassword) async {
    _setLoading(true);
    try {
      await _authService.requestRegister(
        email: email,
        password: password,
        confirmPassword: confirmPassword,
      );
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// STEP 2: verify code -> create user -> login (token saved)
  Future<bool> verifyRegister(String email, String code) async {
    _setLoading(true);
    try {
      final res = await _authService.verifyRegister(email: email, code: code);

      _user = res.user;
      _error = null;

      return true;
    } catch (e) {
      _user = null;
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> forgotPassword(String email) async {
    _setLoading(true);
    try {
      await _authService.forgotPassword(email: email);
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> resetPassword(String token, String newPassword) async {
    _setLoading(true);
    try {
      await _authService.resetPassword(token: token, newPassword: newPassword);
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _authService.logout(); // clears token from TokenStorage
    _user = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  Future<void> refreshMe() async {
    try {
      final me = await _authService.me();
      _user = me;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> deleteAccount() async {
    await _authService.deleteMyAccount();
    await logout();
  }
}
