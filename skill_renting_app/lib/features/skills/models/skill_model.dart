class SkillModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final double price;
  final String pricingUnit;
  final double rating;

  SkillModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.pricingUnit,
    required this.rating,
  });

  factory SkillModel.fromJson(Map<String, dynamic> json) {
    return SkillModel(
      id: json["_id"],
      title: json["title"],
      description: json["description"],
      category: json["category"],
      price: (json["pricing"]["amount"] as num).toDouble(),
      pricingUnit: json["pricing"]["unit"],
      rating: (json["rating"] as num).toDouble(),
    );
  }
}
