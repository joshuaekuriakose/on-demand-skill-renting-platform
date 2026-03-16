import '../../core/services/api_service.dart';
import '../../core/services/auth_storage.dart';

class MessageService {
  static Future<List<Map<String, dynamic>>> fetchMessages(
      String bookingId) async {
    final token = await AuthStorage.getToken();
    if (token == null) return [];
    final res =
        await ApiService.get("/messages/$bookingId", token: token);
    if (res["statusCode"] == 200 && res["data"] is List) {
      return (res["data"] as List)
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>?> sendMessage(
      String bookingId, String text) async {
    final token = await AuthStorage.getToken();
    if (token == null) return null;
    final res = await ApiService.post(
      "/messages/$bookingId",
      {"text": text},
      token: token,
    );
    if (res["statusCode"] == 201 && res["data"] is Map) {
      return Map<String, dynamic>.from(res["data"] as Map);
    }
    return null;
  }

  static Future<int> getUnreadCount(String bookingId) async {
    final token = await AuthStorage.getToken();
    if (token == null) return 0;
    final res = await ApiService.get(
        "/messages/$bookingId/unread-count",
        token: token);
    if (res["statusCode"] == 200) {
      return (res["data"]?["count"] as num?)?.toInt() ?? 0;
    }
    return 0;
  }
}
