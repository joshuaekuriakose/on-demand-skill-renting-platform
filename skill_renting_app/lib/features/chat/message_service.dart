import '../../core/services/api_service.dart';
import '../../core/services/auth_storage.dart';

class MessageService {
  // ── Booking chat ─────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchMessages(
      String bookingId) async {
    final token = await AuthStorage.getToken();
    if (token == null) return [];
    final res = await ApiService.get("/messages/$bookingId", token: token);
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

  // ── Direct chat (seeker → provider from Explore) ─────────────────────────────

  /// Seeker sends a message to any provider.
  /// Creates the conversation on first send; subsequent sends reuse it.
  /// Returns { conversationId, message } on success, or null on failure.
  static Future<Map<String, dynamic>?> startDirectChat({
    required String providerId,
    required String text,
    String? skillId,
  }) async {
    final token = await AuthStorage.getToken();
    if (token == null) return null;
    final body = <String, dynamic>{
      "providerId": providerId,
      "text": text,
      if (skillId != null) "skillId": skillId,
    };
    final res = await ApiService.post("/messages/direct", body, token: token);
    if (res["statusCode"] == 201 && res["data"] is Map) {
      return Map<String, dynamic>.from(res["data"] as Map);
    }
    return null;
  }

  /// Fetch all messages in a direct conversation.
  static Future<List<Map<String, dynamic>>> fetchDirectMessages(
      String conversationId) async {
    final token = await AuthStorage.getToken();
    if (token == null) return [];
    final res = await ApiService.get(
        "/messages/direct/$conversationId",
        token: token);
    if (res["statusCode"] == 200 && res["data"] is List) {
      return (res["data"] as List)
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList();
    }
    return [];
  }

  /// Send a message in an existing direct conversation (seeker or provider).
  static Future<Map<String, dynamic>?> sendDirectMessage(
      String conversationId, String text) async {
    final token = await AuthStorage.getToken();
    if (token == null) return null;
    final res = await ApiService.post(
      "/messages/direct/$conversationId",
      {"text": text},
      token: token,
    );
    if (res["statusCode"] == 201 && res["data"] is Map) {
      return Map<String, dynamic>.from(res["data"] as Map);
    }
    return null;
  }

  static Future<int> getDirectUnreadCount(String conversationId) async {
    final token = await AuthStorage.getToken();
    if (token == null) return 0;
    final res = await ApiService.get(
        "/messages/direct/$conversationId/unread-count",
        token: token);
    if (res["statusCode"] == 200) {
      return (res["data"]?["count"] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  // ── Unified ──────────────────────────────────────────────────────────────────

  static Future<int> getTotalUnread() async {
    final token = await AuthStorage.getToken();
    if (token == null) return 0;
    final res = await ApiService.get("/messages/unread-total", token: token);
    if (res["statusCode"] == 200) {
      return (res["data"]?["count"] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  /// Returns the unified chat list (booking chats with messages + direct chats).
  /// Each item has: chatId, chatType ("booking"|"direct"), skillTitle,
  /// otherPersonName, status, latestMessage, unreadCount.
  static Future<List<Map<String, dynamic>>> getChatList() async {
    final token = await AuthStorage.getToken();
    if (token == null) return [];
    final res = await ApiService.get("/messages", token: token);
    if (res["statusCode"] == 200 && res["data"] is List) {
      return (res["data"] as List)
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList();
    }
    return [];
  }
}
