import '../../core/services/api_service.dart';
import 'models/skill_model.dart';

class SkillService {
  static Future<List<SkillModel>> fetchSkills() async {
    final response = await ApiService.get("/skills");

    if (response["statusCode"] == 200) {
      return (response["data"] as List)
          .map((json) => SkillModel.fromJson(json))
          .toList();
    }
    return [];
  }
}
