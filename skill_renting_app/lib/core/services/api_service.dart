import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class ApiService {
  static dynamic _tryDecodeBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return body;
    }
  }

  static Map<String, dynamic> _wrapResponse(http.Response response) {
    final decoded = _tryDecodeBody(response.body);

    dynamic data = decoded;
    String? message;

    if (decoded is Map) {
      if (decoded.containsKey("data")) data = decoded["data"];
      if (decoded.containsKey("message") && decoded["message"] != null) {
        message = decoded["message"].toString();
      }
    }

    return {
      "statusCode": response.statusCode,
      "data": data,
      "message": message,
    };
  }

  static Future<Map<String, dynamic>> post(
  String endpoint,
  Map<String, dynamic> body, {
  String? token,
}) async {
  final response = await http.post(
    Uri.parse("${ApiConstants.baseUrl}$endpoint"),
    headers: {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    },
    body: jsonEncode(body),
  );

  return _wrapResponse(response);
}

  static Future<Map<String, dynamic>> get(
  String endpoint, {
  String? token,
}) async {
  final response = await http.get(
    Uri.parse("${ApiConstants.baseUrl}$endpoint"),
    headers: {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    },
  );

  return _wrapResponse(response);
}

static Future<Map<String, dynamic>> put(
  String endpoint,
  Map<String, dynamic> body, {
  String? token,
}) async {

  final response = await http.put(
    Uri.parse("${ApiConstants.baseUrl}$endpoint"),
    headers: {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    },
    body: jsonEncode(body),
  );

  return _wrapResponse(response);
}

static Future<Map<String, dynamic>> delete(
  String endpoint, {
  String? token,
}) async {
  final response = await http.delete(
    Uri.parse("${ApiConstants.baseUrl}$endpoint"),
    headers: {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    },
  );

  return _wrapResponse(response);
}

}
