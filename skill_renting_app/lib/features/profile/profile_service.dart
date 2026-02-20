import '../../core/services/api_service.dart';
import '../../core/services/auth_storage.dart';
import 'models/profile_model.dart';
class ProfileService {
  static Future<ProfileModel?> getProfile() async {
  final token = await AuthStorage.getToken();

  if (token == null) return null;

  final response = await ApiService.get(
    "/users/me",
    token: token,
  );

  if (response["statusCode"] == 200) {
    return ProfileModel.fromJson(response["data"]);
  }

  return null;
}

  static Future<bool> updateProfile(String name, String phone) async {
    final token = await AuthStorage.getToken();

    if (token == null) return false;

    final response = await ApiService.put(
      "/users/me",
      {
        "name": name,
        "phone": phone,
      },
      token: token,
    );

    return response["statusCode"] == 200;
  }
}
