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

  final decoded = jsonDecode(response.body);

  return {
    "statusCode": response.statusCode,
    "data": decoded, // ALWAYS here
  };
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

  final decoded = jsonDecode(response.body);

  // If backend returns LIST directly
  if (decoded is List) {
    return {
      "statusCode": response.statusCode,
      "data": decoded,
    };
  }

  // If backend returns MAP { data: ... }
  if (decoded is Map && decoded.containsKey("data")) {
    return {
      "statusCode": response.statusCode,
      "data": decoded["data"],
    };
  }

  // Error fallback
  return {
    "statusCode": response.statusCode,
    "data": decoded,
  };
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

  final decoded = jsonDecode(response.body);

  print("RAW RESPONSE: ${response.body}");
print("DECODED: $decoded");

  return {
    "statusCode": response.statusCode,
    "data": decoded["data"],
    "message": decoded["message"],
  };
}

static Future<Map<String, dynamic>> delete(
  String endpoint, {
  String? token,
}) async {
  final response = await http.delete(
    Uri.parse("${ApiConstants.baseUrl}$endpoint"),
    headers: {
      if (token != null) "Authorization": "Bearer $token",
    },
  );

   final decoded = jsonDecode(response.body);

   print("RAW RESPONSE: ${response.body}");
print("DECODED: $decoded");

  return {
    "statusCode": response.statusCode,
    "data": decoded["data"],
    "message": decoded["message"],
  };
}

}
