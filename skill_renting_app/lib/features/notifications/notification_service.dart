import '../../core/services/api_service.dart';
import '../../core/services/auth_storage.dart';

class NotificationService {
  static Future<List> fetchNotifications() async {
    final token = await AuthStorage.getToken();
    if (token == null) return [];
    final response = await ApiService.get("/notifications", token: token);
    if (response["statusCode"] == 200) return response["data"];
    return [];
  }

  static Future<void> markRead(String id) async {
    final token = await AuthStorage.getToken();
    if (token == null) return;
    await ApiService.put("/notifications/$id/read", {}, token: token);
  }

  static Future<bool> markAllRead() async {
    final token = await AuthStorage.getToken();
    if (token == null) return false;
    final res = await ApiService.put("/notifications/read-all", {}, token: token);
    return res["statusCode"] == 200;
  }

  static Future<int> fetchUnreadCount() async {
    final token = await AuthStorage.getToken();
    if (token == null) return 0;
    final response =
        await ApiService.get("/notifications/unread-count", token: token);
    if (response["statusCode"] == 200) return (response["data"]?["count"] as num?)?.toInt() ?? 0;
    return 0;
  }
}
