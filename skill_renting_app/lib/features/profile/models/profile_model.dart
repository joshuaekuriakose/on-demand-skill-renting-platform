class ProfileModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final Map<String, dynamic>? address;

  ProfileModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.address,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json["_id"] ?? "",
      name: json["name"] ?? "",
      email: json["email"] ?? "",
      phone: json["phone"] ?? "",
      address: json["address"] is Map<String, dynamic>
          ? json["address"] as Map<String, dynamic>
          : null,
    );
  }
}