import '../../core/services/api_service.dart';
import 'models/user_model.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';

class AuthService {

  // ================= LOGIN =================
  static Future<UserModel?> login(
    String email,
    String password,
  ) async {

    final response = await ApiService.post(
      "/auth/login",
      {
        "email": email,
        "password": password,
      },
    );

    if (response["statusCode"] == 200) {

      // ✅ FIX: Correct variable name
      final data = response["data"];

      // ✅ Save token + name
      await AuthStorage.saveAuthData(
        data["token"],
        data["name"],
      );

      return UserModel.fromJson(data);
    }

    return null;
  }


  // ================= REGISTER =================
  static Future<UserModel?> register(
    String name,
    String email,
    String phone,
    String password,
  ) async {

    final response = await ApiService.post(
      "/auth/register",
      {
        "name": name,
        "email": email,
        "phone": phone,
        "password": password,
      },
    );

    if (response["statusCode"] == 201) {

      final data = response["data"];

      // ✅ Save token + name
      await AuthStorage.saveAuthData(
        data["token"],
        data["name"],
      );

      return UserModel.fromJson(data);
    }

    return null;
  }


  // ================= CHANGE PASSWORD =================
  static Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {

    final token = await AuthStorage.getToken();

    if (token == null) return false;

    final response = await ApiService.put(
      "/auth/change-password",
      {
        "currentPassword": currentPassword,
        "newPassword": newPassword,
      },
      token: token,
    );

    return response["statusCode"] == 200;
  }

}