import '../../core/services/api_service.dart';
import '../../core/services/auth_storage.dart';
import 'models/booking_model.dart';

class BookingService {
  static Future<bool> createBooking({
  required String skillId,
  required DateTime startDate,
  required DateTime endDate,
  required int duration,
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
    },
    token: token,
  );

  if (response["statusCode"] != 201) {
    final msg = response["data"]?["message"] ?? "Booking failed";
    throw Exception(msg);
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

    print("✅ Length: ${list.length}");

    return list
        .map((json) => BookingModel.fromJson(json))
        .toList();
  }

  return [];
}


static Future<List<BookingModel>> fetchMyBookings() async {
  final token = await AuthStorage.getToken();

  if (token == null) {
    print(" No token (seeker)");
    return [];
  }

  final response = await ApiService.get(
    "/bookings/my",
    token: token,
  );

  if (response["statusCode"] == 200) {
    final data = response["data"];

    if (data is List) {
      print("✅ Length: ${data.length}");

      return data
          .map((json) => BookingModel.fromJson(json))
          .toList();
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



}