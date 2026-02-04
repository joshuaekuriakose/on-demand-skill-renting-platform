import '../../core/services/api_service.dart';
import '../../core/services/auth_storage.dart';
import 'models/booking_model.dart';

class BookingService {
  static Future<bool> createBooking(String skillId) async {
  final token = await AuthStorage.getToken();

  if (token == null) {
    print("No token found");
    return false;
  }

  final response = await ApiService.post(
    "/bookings",
    {
      "skillId": skillId,
    },
    token: token,
  );

  print("Booking status: ${response["statusCode"]}");
  print("Booking response: ${response["data"]}");

  return response["statusCode"] == 201;
}

static Future<List<BookingModel>> fetchProviderBookings() async {
  final token = await AuthStorage.getToken();

  if (token == null) {
    print("❌ No token");
    return [];
  }

  final response = await ApiService.get(
    "/bookings/provider",
    token: token,
  );

  print("📡 Status: ${response["statusCode"]}");
  print("📦 Raw Data: ${response["data"]}");

  if (response["statusCode"] == 200) {
    final data = response["data"];

    if (data is List) {
      print("✅ List length: ${data.length}");

      return data
          .map((json) {
            print("➡️ Item: $json");
            return BookingModel.fromJson(json);
          })
          .toList();
    } else {
      print("❌ Data is not a List");
    }
  }

  return [];
}

static Future<void> updateBookingStatus(
  String bookingId,
  String action,
) async {

  final token = await AuthStorage.getToken();

  if (token == null) return;

  await ApiService.put(
    "/bookings/$bookingId/$action",
    {},
    token: token,
  );
}



}