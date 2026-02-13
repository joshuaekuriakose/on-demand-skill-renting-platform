import '../../core/services/api_service.dart';
import '../../core/services/auth_storage.dart';
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

  static Future<List<dynamic>> fetchMySkills() async {
    final token = await AuthStorage.getToken();

    if (token == null) return [];

    final response = await ApiService.get(
      "/skills/my",
      token: token,
    );

    if (response["statusCode"] == 200) {
      return response["data"];
    }

    return [];
  }

  static Future<bool> updateSkill(
  String id,
  Map<String, dynamic> data,
) async {
  final token = await AuthStorage.getToken();

  if (token == null) return false;

  final response = await ApiService.put(
    "/skills/$id",
    data,
    token: token,
  );

  return response["statusCode"] == 200;
}

static Future<bool> deleteSkill(String id) async {
  final token = await AuthStorage.getToken();

  if (token == null) return false;

  final response = await ApiService.delete(
    "/skills/$id",
    token: token,
  );

  return response["statusCode"] == 200;
}

static Future<List<SkillModel>> searchSkills(String query) async {
  // Get all skills
  final allSkills = await fetchSkills();
  
  // If no query, return all
  if (query.isEmpty) return allSkills;
  
  // Filter locally
  final lowerQuery = query.toLowerCase();
  return allSkills.where((skill) {
    return skill.title.toLowerCase().contains(lowerQuery) ||
           skill.category.toLowerCase().contains(lowerQuery) ||
           skill.description.toLowerCase().contains(lowerQuery);
  }).toList();
}


}