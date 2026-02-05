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
  return BookingModel(
    id: json["_id"] ?? "",
    status: json["status"] ?? "",

    // Skill
   skillId: json["skill"] is Map
    ? json["skill"]["_id"] ?? ""
    : "",

skillTitle: json["skill"] is Map
    ? json["skill"]["title"] ?? ""
    : "",


    // Seeker (object or id)
    seekerName: json["seeker"] is Map
        ? json["seeker"]["name"] ?? "Unknown"
        : "You",

    // Provider (object or id)
    providerName: json["provider"] is Map
        ? json["provider"]["name"] ?? "Unknown"
        : "Provider",
        
      isReviewed: json["isReviewed"] ?? false,

  );
}


}
