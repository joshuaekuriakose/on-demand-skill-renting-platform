import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const _tokenKey = "auth_token";
  static const _nameKey  = "user_name";
  static const _roleKey  = "user_role";

  static const _idKey = "user_id";

  static Future<void> saveAuthData(String token, String name, {String role = "user", String userId = ""}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_nameKey,  name);
    await prefs.setString(_roleKey,  role);
    if (userId.isNotEmpty) await prefs.setString(_idKey, userId);
  }

  static Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_idKey) ?? "";
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nameKey);
  }

  static Future<String> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey) ?? "user";
  }

  static Future<bool> isAdmin() async => (await getRole()) == "admin";

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
