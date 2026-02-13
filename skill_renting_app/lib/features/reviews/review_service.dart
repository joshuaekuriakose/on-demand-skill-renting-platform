import '../../core/services/api_service.dart';

class ReviewService {
  static Future<List> fetchSkillReviews(String skillId) async {
    final response = await ApiService.get(
      "/reviews/skill/$skillId",
    );

    if (response["statusCode"] == 200) {
      return response["data"];
    }

    return [];
  }
}
