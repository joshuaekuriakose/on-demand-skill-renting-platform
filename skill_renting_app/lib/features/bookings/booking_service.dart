import '../../core/services/api_service.dart';
import '../../core/services/auth_storage.dart';
import 'models/booking_model.dart';

class BookingService {
  static String _extractErrorMessage(Map<String, dynamic> response,
      {String fallback = "Request failed"}) {
    final msg = response["message"];
    if (msg != null && msg.toString().trim().isNotEmpty) {
      return msg.toString();
    }

    final data = response["data"];
    if (data is Map && data["message"] != null) {
      final m = data["message"].toString();
      if (m.trim().isNotEmpty) return m;
    }

    return fallback;
  }

  static Future<bool> createBooking({
    required String skillId,
    required DateTime startDate,
    required DateTime endDate,
    required int duration,
    required String description,
    required Map<String, String> jobAddress,
  }) async {
    final token = await AuthStorage.getToken();

    if (token == null) {
      print("No token found");
      return false;
    }

    final response = await ApiService.post(
      "/bookings",
      {
        "skillId": skillId,
        "startDate": startDate.toIso8601String(),
        "endDate": endDate.toIso8601String(),
        "duration": duration,
        "jobAddress": jobAddress,
        "jobDescription": description,
      },
      token: token,
    );

    if (response["statusCode"] != 201) {
      throw Exception(
          _extractErrorMessage(response, fallback: "Booking failed"));
    }

    return true;
  }

  static Future<List<BookingModel>> fetchProviderBookings() async {
    final token = await AuthStorage.getToken();

    if (token == null) {
      print("No token found");
      return [];
    }

    final response = await ApiService.get(
      "/bookings/provider",
      token: token,
    );

    if (response["statusCode"] == 200) {
      final list = response["data"] as List;
      return list.map((json) => BookingModel.fromJson(json)).toList();
    }

    return [];
  }

  static Future<List<BookingModel>> fetchMyBookings() async {
    final token = await AuthStorage.getToken();

    if (token == null) {
      print("No token (seeker)");
      return [];
    }

    final response = await ApiService.get(
      "/bookings/my",
      token: token,
    );

    if (response["statusCode"] == 200) {
      final data = response["data"];

      if (data is List) {
        return data.map((json) => BookingModel.fromJson(json)).toList();
      }
    }

    return [];
  }

  static Future<bool> updateBookingStatus(
    String bookingId,
    String action,
  ) async {
    final token = await AuthStorage.getToken();

    if (token == null) return false;

    final response = await ApiService.put(
      "/bookings/$bookingId/$action",
      {},
      token: token,
    );

    return response["statusCode"] == 200;
  }

  // ── GPS ─────────────────────────────────────────────────────────────────────

  /// Seeker submits the GPS location for an accepted booking.
  /// [saveAsHome] will persist the location as the seeker's home GPS.
  static Future<bool> submitJobGps({
    required String bookingId,
    required double lat,
    required double lng,
    bool saveAsHome = false,
  }) async {
    final token = await AuthStorage.getToken();
    if (token == null) return false;

    final response = await ApiService.put(
      "/bookings/$bookingId/gps",
      {
        "lat": lat,
        "lng": lng,
        "saveAsHome": saveAsHome,
      },
      token: token,
    );

    return response["statusCode"] == 200;
  }

  /// Seeker skips GPS sharing for this booking.
  static Future<bool> skipJobGps(String bookingId) async {
    final token = await AuthStorage.getToken();
    if (token == null) return false;

    final response = await ApiService.put(
      "/bookings/$bookingId/skip-gps",
      {},
      token: token,
    );

    return response["statusCode"] == 200;
  }

  // ────────────────────────────────────────────────────────────────────────────

  static Future<List<dynamic>> fetchOccupiedSlots(
    String skillId,
    String date,
  ) async {
    final token = await AuthStorage.getToken();

    final response = await ApiService.get(
      "/bookings/occupied/$skillId?date=$date",
      token: token,
    );

    if (response["statusCode"] == 200) {
      return response["data"];
    }

    throw Exception(_extractErrorMessage(response, fallback: "Failed"));
  }

  static Future<List<dynamic>> fetchAllOccupiedSlots(
    String skillId,
  ) async {
    final token = await AuthStorage.getToken();

    if (token == null) {
      throw Exception("Unauthorized");
    }

    final response = await ApiService.get(
      "/bookings/occupied-range/$skillId",
      token: token,
    );

    if (response["statusCode"] == 200) {
      return response["data"];
    }

    throw Exception(_extractErrorMessage(response, fallback: "Failed"));
  }

  static Future<void> toggleBlockedSlot({
    required String skillId,
    required DateTime start,
    required DateTime end,
    String? reason,
  }) async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      throw Exception("Unauthorized");
    }

    final response = await ApiService.post(
      "/bookings/blocks/toggle",
      {
        "skillId": skillId,
        "startDate": start.toIso8601String(),
        "endDate": end.toIso8601String(),
        if (reason != null && reason.trim().isNotEmpty) "reason": reason,
      },
      token: token,
    );

    if (response["statusCode"] != 200 && response["statusCode"] != 201) {
      throw Exception(
        _extractErrorMessage(
          response,
          fallback: "Failed to update slot",
        ),
      );
    }
  }
}
