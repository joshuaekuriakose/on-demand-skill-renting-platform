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

  static Future<bool> updateProfile(
    String name,
    String phone, {
    Map<String, String>? address,
  }) async {
    final token = await AuthStorage.getToken();

    if (token == null) return false;

    final body = {
      "name": name,
      "phone": phone,
      if (address != null) "address": address,
    };

    final response = await ApiService.put(
      "/users/me",
      body,
      token: token,
    );

    return response["statusCode"] == 200;
  }
}
