import '../../core/services/api_service.dart';
import 'models/user_model.dart';

class AuthService {
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
      return UserModel.fromJson(response["data"]);
    }
    return null;
  }

  static Future<UserModel?> register(
    String name,
    String email,
    String phone,
    String password,
    String role,
  ) async {
    final response = await ApiService.post(
      "/auth/register",
      {
        "name": name,
        "email": email,
        "phone": phone,
        "password": password,
        "role": role,
      },
    );

    if (response["statusCode"] == 201) {
      return UserModel.fromJson(response["data"]);
    }
    return null;
  }
}
