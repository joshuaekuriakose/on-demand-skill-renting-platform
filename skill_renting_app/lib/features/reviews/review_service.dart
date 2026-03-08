import '../../core/services/api_service.dart';
import '../../core/services/auth_storage.dart';

class ReviewService {
  // Public — no token needed
  static Future<List> fetchSkillReviews(String skillId) async {
    final response = await ApiService.get("/reviews/skill/$skillId");
    if (response["statusCode"] == 200) {
      return response["data"];
    }
    return [];
  }

  // Provider replies to a review
  static Future<bool> replyToReview(String reviewId, String text) async {
    final token = await AuthStorage.getToken();
    if (token == null) return false;

    final response = await ApiService.put(
      "/reviews/$reviewId/reply",
      {"text": text},
      token: token,
    );
    return response["statusCode"] == 200;
  }

  // Provider deletes their reply
  static Future<bool> deleteReply(String reviewId) async {
    final token = await AuthStorage.getToken();
    if (token == null) return false;

    final response = await ApiService.delete(
      "/reviews/$reviewId/reply",
      token: token,
    );
    return response["statusCode"] == 200;
  }
}
