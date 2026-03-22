class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String token;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:    json["_id"]?.toString()    ?? "",
      name:  json["name"]?.toString()   ?? "",
      email: json["email"]?.toString()  ?? "",
      role:  json["role"]?.toString()   ?? "user",
      token: json["token"]?.toString()  ?? "",
    );
  }
}
