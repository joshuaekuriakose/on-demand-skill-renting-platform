import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const _tokenKey = "auth_token";
  static const _nameKey = "user_name";

  // Save token + name
  static Future<void> saveAuthData(String token, String name) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_tokenKey, token);
    await prefs.setString(_nameKey, name);
  }

  // Get token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Get name
  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_nameKey); //New
  
    return prefs.getString(_nameKey);
  }

  // Clear everything
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}