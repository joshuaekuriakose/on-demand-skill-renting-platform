import '../../core/services/api_service.dart';
import '../../core/services/auth_storage.dart';

class AdminService {
  static Future<String?> _token() => AuthStorage.getToken();

  static Future<Map<String, dynamic>> getStats() async {
    final t = await _token();
    final r = await ApiService.get("/admin/stats", token: t);
    if (r["statusCode"] == 200) return Map<String, dynamic>.from(r["data"] as Map);
    return {};
  }

  static Future<Map<String, dynamic>> getUsers({
    String? role, String? search, int page = 1,
  }) async {
    final t = await _token();
    String q = "/admin/users?page=$page&limit=30";
    if (role   != null) q += "&role=$role";
    if (search != null && search.isNotEmpty) q += "&search=$search";
    final r = await ApiService.get(q, token: t);
    if (r["statusCode"] == 200) return Map<String, dynamic>.from(r["data"] as Map);
    return {"users": [], "total": 0};
  }

  static Future<Map<String, dynamic>?> getUserDetail(String id) async {
    final t = await _token();
    final r = await ApiService.get("/admin/users/$id", token: t);
    if (r["statusCode"] == 200) return Map<String, dynamic>.from(r["data"] as Map);
    return null;
  }

  static Future<Map<String, dynamic>> getBookings({
    String? status, String? search,
    String? dateFrom, String? dateTo, int page = 1,
  }) async {
    final t = await _token();
    String q = "/admin/bookings?page=$page&limit=30";
    if (status   != null) q += "&status=$status";
    if (search   != null && search.isNotEmpty) q += "&search=$search";
    if (dateFrom != null) q += "&dateFrom=$dateFrom";
    if (dateTo   != null) q += "&dateTo=$dateTo";
    final r = await ApiService.get(q, token: t);
    if (r["statusCode"] == 200) return Map<String, dynamic>.from(r["data"] as Map);
    return {"bookings": [], "total": 0};
  }

  static Future<Map<String, dynamic>> getRevenue({
    String? dateFrom, String? dateTo, int page = 1,
  }) async {
    final t = await _token();
    String q = "/admin/revenue?page=$page&limit=50";
    if (dateFrom != null) q += "&dateFrom=$dateFrom";
    if (dateTo   != null) q += "&dateTo=$dateTo";
    final r = await ApiService.get(q, token: t);
    if (r["statusCode"] == 200) return Map<String, dynamic>.from(r["data"] as Map);
    return {"bookings": [], "total": 0, "grandTotal": 0};
  }

  static Future<List> getBookingsBySkill({
    String? search, String? dateFrom, String? dateTo,
  }) async {
    final t = await _token();
    String q = "/admin/bookings/skills?";
    if (search   != null && search.isNotEmpty) q += "search=$search&";
    if (dateFrom != null) q += "dateFrom=$dateFrom&";
    if (dateTo   != null) q += "dateTo=$dateTo&";
    final r = await ApiService.get(q, token: t);
    if (r["statusCode"] == 200 && r["data"] is List) return r["data"] as List;
    return [];
  }

  static Future<List> getBookingsForSkill(String skillId, {
    String? status, String? dateFrom, String? dateTo,
  }) async {
    final t = await _token();
    String q = "/admin/bookings/skill/$skillId?";
    if (status   != null) q += "status=$status&";
    if (dateFrom != null) q += "dateFrom=$dateFrom&";
    if (dateTo   != null) q += "dateTo=$dateTo&";
    final r = await ApiService.get(q, token: t);
    if (r["statusCode"] == 200 && r["data"] is List) return r["data"] as List;
    return [];
  }

  static Future<List<String>> getDistricts() async {
    final t = await _token();
    final r = await ApiService.get("/admin/districts", token: t);
    if (r["statusCode"] == 200 && r["data"] is List)
      return (r["data"] as List).map((e) => e.toString()).toList();
    return [];
  }

  static Future<Map<String, dynamic>> generateUserReport({
    required String userId,
    required DateTime dateFrom, required DateTime dateTo,
  }) async {
    final t = await _token();
    final r = await ApiService.post("/admin/reports/user",
      {"userId": userId, "dateFrom": dateFrom.toIso8601String(), "dateTo": dateTo.toIso8601String()},
      token: t);
    if (r["statusCode"] == 200) return Map<String, dynamic>.from(r["data"] as Map);
    return {"error": r["message"] ?? "Failed"};
  }

  static Future<Map<String, dynamic>> generateProviderReport({
    required String providerId,
    required DateTime dateFrom, required DateTime dateTo,
  }) async {
    final t = await _token();
    final r = await ApiService.post("/admin/reports/provider",
      {"providerId": providerId, "dateFrom": dateFrom.toIso8601String(), "dateTo": dateTo.toIso8601String()},
      token: t);
    if (r["statusCode"] == 200) return Map<String, dynamic>.from(r["data"] as Map);
    return {"error": r["message"] ?? "Failed"};
  }

  static Future<Map<String, dynamic>> generateBulkUserReport({
    String? role, String? district, String? pricingUnit,
    required DateTime dateFrom, required DateTime dateTo,
  }) async {
    final t = await _token();
    final body = <String, dynamic>{
      "dateFrom": dateFrom.toIso8601String(),
      "dateTo":   dateTo.toIso8601String(),
    };
    if (role        != null) body["role"]        = role;
    if (district    != null) body["district"]    = district;
    if (pricingUnit != null) body["pricingUnit"] = pricingUnit;
    final r = await ApiService.post("/admin/reports/bulk-users", body, token: t);
    if (r["statusCode"] == 200) return Map<String, dynamic>.from(r["data"] as Map);
    return {"error": r["message"] ?? "Failed"};
  }

  static Future<Map<String, dynamic>> generateBookingsReport({
    String? skillId, String? status,
    required DateTime dateFrom, required DateTime dateTo,
  }) async {
    final t = await _token();
    final body = <String, dynamic>{
      "dateFrom": dateFrom.toIso8601String(),
      "dateTo":   dateTo.toIso8601String(),
    };
    if (skillId != null) body["skillId"] = skillId;
    if (status  != null) body["status"]  = status;
    final r = await ApiService.post("/admin/reports/bookings", body, token: t);
    if (r["statusCode"] == 200) return Map<String, dynamic>.from(r["data"] as Map);
    return {"error": r["message"] ?? "Failed"};
  }
}
