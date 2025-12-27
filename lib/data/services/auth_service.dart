import '../models/auth_response.dart';
import '../models/users.dart';
import 'api_service.dart';
import 'token_storage.dart';

class AuthService {
  AuthService({
    ApiService? api,
    TokenStorage? tokenStorage,
  })  : _api = api ?? ApiService(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiService _api;
  final TokenStorage _tokenStorage;

  Future<String?> getToken() => _tokenStorage.getToken();
  Future<bool> hasToken() => _tokenStorage.hasToken();
  Future<void> logout() => _tokenStorage.clearToken();

  /// POST /auth/login  -> returns JWT + user and saves token
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final data = await _api.post(
      "/auth/login",
      body: {"email": email.trim(), "password": password},
      auth: false,
    );

    final res = AuthResponse.fromJson(data);

    if (res.token.isNotEmpty) {
      await _tokenStorage.saveToken(res.token);
    }

    return res;
  }

  /// STEP 1:
  /// POST /auth/register -> sends verification code to email
  Future<void> requestRegister({
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    await _api.post(
      "/auth/register",
      body: {
        "email": email.trim(),
        "password": password,
        "confirmPassword": confirmPassword,
      },
      auth: false,
    );
  }

  /// STEP 2:
  /// POST /auth/register/verify -> creates user and returns JWT + user (saves token)
  Future<AuthResponse> verifyRegister({
    required String email,
    required String code,
  }) async {
    final data = await _api.post(
      "/auth/register/verify",
      body: {"email": email.trim(), "code": code.trim()},
      auth: false,
    );

    final res = AuthResponse.fromJson(data);

    if (res.token.isNotEmpty) {
      await _tokenStorage.saveToken(res.token);
    }

    return res;
  }

  /// POST /auth/forgot-password (public)
  Future<void> forgotPassword({required String email}) async {
    await _api.post(
      "/auth/forgot-password",
      body: {"email": email.trim()},
      auth: false,
    );
  }

  /// POST /auth/reset-password (public)
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _api.post(
      "/auth/reset-password",
      body: {"token": token.trim(), "newPassword": newPassword},
      auth: false,
    );
  }

  /// GET /me (protected) -> returns current user from token
  Future<User> me() async {
    final data = await _api.get("/me", auth: true);

    if (data is Map) {
      dynamic payload = data;

      if (data["user"] is Map) {
        payload = data["user"];
      } else if (data["data"] is Map) {
        final d = data["data"] as Map;
        if (d["user"] is Map) {
          payload = d["user"];
        } else {
          payload = d;
        }
      }

      if (payload is Map) {
        return User.fromJson(Map<String, dynamic>.from(payload));
      }
    }

    throw Exception("Invalid /me response (expected JSON object)");
  }

  Future<void> deleteMyAccount() async {
    await _api.delete("/me", auth: true);
  }
}
