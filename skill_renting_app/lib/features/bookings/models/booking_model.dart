class BookingModel {
  final String id;
  final String status;
  final String skillTitle;
  final String seekerName;
  final String providerName;
  final String skillId;
  final bool isReviewed;

  BookingModel({
    required this.id,
    required this.status,
    required this.skillTitle,
    required this.seekerName,
    required this.providerName,
    required this.skillId,
    required this.isReviewed,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {

    final skill = json["skill"];
    final seeker = json["seeker"];
    final provider = json["provider"];

    return BookingModel(
      // ID
      id: json["_id"] ?? "",

      // Status
      status: json["status"] ?? "unknown",

      // Skill
      skillId: skill is Map
          ? skill["_id"] ?? ""
          : "",

      skillTitle: skill is Map
          ? skill["title"] ?? "Unknown Skill"
          : "Unknown Skill",

      // Seeker
      seekerName: seeker is Map
          ? seeker["name"] ?? "Unknown"
          : "Unknown",

      // Provider
      providerName: provider is Map
          ? provider["name"] ?? "Unknown"
          : "Unknown",

      // Review
      isReviewed: json["isReviewed"] == true,
    );
  }
}
