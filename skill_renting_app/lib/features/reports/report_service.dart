import '../../core/services/api_service.dart';
import '../../core/services/auth_storage.dart';
import 'report_model.dart';

class ReportService {
  // Generate a custom report for a date range
  // Returns null if empty, throws on error
  static Future<Map<String, dynamic>> generateCustomReport({
    required String skillId,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    final token = await AuthStorage.getToken();
    if (token == null) return {"error": "Not authenticated"};

    final res = await ApiService.post(
      "/reports/generate",
      {
        "skillId":  skillId,
        "dateFrom": dateFrom.toIso8601String(),
        "dateTo":   dateTo.toIso8601String(),
      },
      token: token,
    );

    if (res["statusCode"] == 201) {
      return {"report": ReportModel.fromJson(res["data"] as Map<String, dynamic>)};
    }

    if (res["statusCode"] == 200 && res["data"] is Map) {
      final d = res["data"] as Map;
      if (d["empty"] == true) return {"empty": true};
    }

    return {"error": res["message"] ?? "Failed to generate report"};
  }

  // List all reports for this provider (no reportData blob)
  static Future<List<ReportModel>> fetchMyReports() async {
    final token = await AuthStorage.getToken();
    if (token == null) return [];

    final res = await ApiService.get("/reports", token: token);
    if (res["statusCode"] == 200 && res["data"] is List) {
      return (res["data"] as List)
          .map((j) => ReportModel.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  // Fetch full report with reportData for PDF generation
  static Future<ReportModel?> fetchReportById(String id) async {
    final token = await AuthStorage.getToken();
    if (token == null) return null;

    final res = await ApiService.get("/reports/$id", token: token);
    if (res["statusCode"] == 200) {
      return ReportModel.fromJson(res["data"] as Map<String, dynamic>);
    }
    return null;
  }
}
