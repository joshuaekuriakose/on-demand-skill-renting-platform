import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class ApiService {
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

    return {
      "statusCode": response.statusCode,
      "data": jsonDecode(response.body),
    };
  }

  static Future<Map<String, dynamic>> get(
  String endpoint, {
  String? token,
}) async {
  final response = await http.get(
    Uri.parse("${ApiConstants.baseUrl}$endpoint"),
    headers: {
      if (token != null) "Authorization": "Bearer $token",
    },
  );

  return {
    "statusCode": response.statusCode,
    "data": jsonDecode(response.body),
  };
}

}
