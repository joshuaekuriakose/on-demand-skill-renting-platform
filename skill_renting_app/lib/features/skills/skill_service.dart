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

static Future<List<SkillModel>> searchSkills({
  String? query,
  String? category,
  double? minPrice,
  double? maxPrice,
  double? minRating,
}) async {

  final allSkills = await fetchSkills();

  return allSkills.where((skill) {

    // 🔎 Text Search
    if (query != null && query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      final matchesText =
          skill.title.toLowerCase().contains(lowerQuery) ||
          skill.category.toLowerCase().contains(lowerQuery) ||
          skill.description.toLowerCase().contains(lowerQuery);

      if (!matchesText) return false;
    }

    // 📂 Category Filter
    if (category != null && category.isNotEmpty) {
  final Map<String, List<String>> categoryMap = {
    "Plumbing": ["Plumbing", "Plumber", "Pipe Repair", "Water Works"],
    "Electrical": ["Electrical", "Electrician", "Wiring", "Power Repair"],
    "Appliance Repair": ["Appliance Repair", "Fridge Repair", "AC Repair"],
    "Cleaning": ["Cleaning", "House Cleaning", "Office Cleaning"],
  };

  final allowed = categoryMap[category] ?? [category];

  if (!allowed.contains(skill.category)) {
    return false;
  }
}

    // 💰 Price Filter
    if (minPrice != null && skill.price < minPrice) return false;
    if (maxPrice != null && skill.price > maxPrice) return false;

    // ⭐ Rating Filter
    if (minRating != null && skill.rating < minRating) return false;

    return true;

  }).toList();
}


}