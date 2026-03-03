class BookingModel {
  final String id;
  final String status;
  final String skillTitle;
  final String seekerName;
  final String providerName;
  final String skillId;
  final bool isReviewed;
  final DateTime createdAt;
  
  BookingModel({
    required this.id,
    required this.status,
    required this.skillTitle,
    required this.seekerName,
    required this.providerName,
    required this.skillId,
    required this.isReviewed,
    required this.createdAt,
  });

  BookingModel copyWith({
  String? status,
  bool? isReviewed,
}) {
  return BookingModel(
    id: id,
    status: status ?? this.status,
    skillTitle: skillTitle,
    seekerName: seekerName,
    providerName: providerName,
    skillId: skillId,
    isReviewed: isReviewed ?? this.isReviewed,
    createdAt: createdAt,
  );
}

  factory BookingModel.fromJson(Map<String, dynamic> json) {

    final skill = json["skill"];
    final seeker = json["seeker"];
    final provider = json["provider"];

  return BookingModel(
    id: json["_id"] ?? "",
    status: json["status"] ?? "unknown",

    skillId: skill is Map
        ? skill["_id"] ?? ""
        : "",

    skillTitle: skill is Map
        ? skill["title"] ?? "Unknown Skill"
        : "Unknown Skill",

    seekerName: seeker is Map
        ? seeker["name"] ?? "Unknown"
        : "Unknown",

    providerName: provider is Map
        ? provider["name"] ?? "Unknown"
        : "Unknown",

    isReviewed: json["isReviewed"] == true,

   
    createdAt: DateTime.parse(json["createdAt"]),

  );
  }
  String get createdAtFormatted {
  return "${createdAt.day}/${createdAt.month}/${createdAt.year} "
         "${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}";
}
}
