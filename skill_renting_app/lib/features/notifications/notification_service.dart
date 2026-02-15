import '../../core/services/api_service.dart';
import '../../core/services/auth_storage.dart';

class NotificationService {
  static Future<List> fetchNotifications() async {
    final token = await AuthStorage.getToken();

    if (token == null) return [];

    final response = await ApiService.get(
      "/notifications",
      token: token,
    );

    if (response["statusCode"] == 200) {
      return response["data"];
    }

    return [];
  }

  static Future<void> markRead(String id) async {
    final token = await AuthStorage.getToken();

    if (token == null) return;

    await ApiService.put(
      "/notifications/$id/read",
      {},
      token: token,
    );
  }
}
