class BookingModel {
  final String id;
  final String status;
  final String skillTitle;
  final String seekerName;

  BookingModel({
    required this.id,
    required this.status,
    required this.skillTitle,
    required this.seekerName,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json["_id"] ?? "",
      status: json["status"] ?? "",

      // Safe skill access
      skillTitle: json["skill"] != null
          ? json["skill"]["title"] ?? ""
          : "",

      // Safe seeker access
      seekerName: json["seeker"] != null
          ? json["seeker"]["name"] ?? ""
          : "Unknown",
    );
  }
}
