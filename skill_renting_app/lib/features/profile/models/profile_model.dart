class ProfileModel {
  final String id;
  final String name;
  final String email;
  final String phone;

  ProfileModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json["_id"] ?? "",
      name: json["name"] ?? "",
      email: json["email"] ?? "",
      phone: json["phone"] ?? "",
    );
  }
}