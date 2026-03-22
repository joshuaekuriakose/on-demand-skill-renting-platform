import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/services/api_service.dart';
import 'models/user_model.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';

class AuthService {

  static Future<UserModel?> login(String email, String password) async {
    final response = await ApiService.post(
      "/auth/login",
      {"email": email, "password": password},
    );

    if (response["statusCode"] == 200) {
      final data = response["data"];
      await AuthStorage.saveAuthData(
        data["token"],
        data["name"],
        role:   data["role"]   ?? "user",
        userId: data["_id"]?.toString() ?? "",
      );
      return UserModel.fromJson(data);
    }
    return null;
  }

  static Future<UserModel?> register(
    String name, String email, String phone, String password, {
    required Map<String, String> address,
  }) async {
    final response = await ApiService.post(
      "/auth/register",
      {"name": name, "email": email, "phone": phone,
       "password": password, "address": address},
    );

    if (response["statusCode"] == 201) {
      final data = response["data"];
      await AuthStorage.saveAuthData(
        data["token"],
        data["name"],
        role:   data["role"]   ?? "user",
        userId: data["_id"]?.toString() ?? "",
      );
      return UserModel.fromJson(data);
    }
    return null;
  }

  static Future<bool> changePassword(String currentPassword, String newPassword) async {
    final token = await AuthStorage.getToken();
    if (token == null) return false;
    final response = await ApiService.put(
      "/auth/change-password",
      {"currentPassword": currentPassword, "newPassword": newPassword},
      token: token,
    );
    return response["statusCode"] == 200;
  }

  /// Clears FCM token from server BEFORE wiping local storage.
  /// This prevents the old token from delivering notifications to
  /// the next user who logs in on the same device.
  static Future<void> logout() async {
    try {
      final token = await AuthStorage.getToken();
      if (token != null) {
        // Tell the server this device no longer belongs to this account
        await ApiService.post("/users/save-token", {"token": ""}, token: token);
      }
      // Also unsubscribe from FCM topics / delete the instance ID
      // so a fresh token is issued on next login
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // Best-effort — always clear local storage even if server call fails
    }
    await AuthStorage.clear();
  }
}
