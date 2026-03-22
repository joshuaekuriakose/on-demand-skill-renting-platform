class SkillModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final double price;
  final String pricingUnit;
  final double rating;
  final String providerId;
  final String providerName;
  final String providerLocality;
  final String providerDistrict;
  final String providerPincode;
  final double providerRating;
  final int    providerTotalReviews;

  SkillModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.pricingUnit,
    required this.rating,
    this.providerId            = "",
    this.providerName          = "",
    this.providerLocality      = "",
    this.providerDistrict      = "",
    this.providerPincode       = "",
    this.providerRating        = 0.0,
    this.providerTotalReviews  = 0,
  });

  factory SkillModel.fromJson(Map<String, dynamic> json) {
    final pricing  = json["pricing"];
    final provider = json["provider"];
    return SkillModel(
      id:           json["_id"]?.toString()         ?? "",
      title:        json["title"]?.toString()       ?? "Unknown",
      description:  json["description"]?.toString() ?? "",
      category:     json["category"]?.toString()    ?? "",
      price:        pricing is Map && pricing["amount"] is num
                        ? (pricing["amount"] as num).toDouble()
                        : 0.0,
      pricingUnit:  pricing is Map ? pricing["unit"]?.toString() ?? "hour" : "hour",
      rating:       json["rating"] is num ? (json["rating"] as num).toDouble() : 0.0,
      providerId:           provider is Map ? provider["_id"]?.toString()   ?? "" : "",
      providerName:         provider is Map ? provider["name"]?.toString()  ?? "" : "",
      providerLocality:     provider is Map
          ? (provider["address"] is Map
              ? (provider["address"]["locality"]?.toString() ?? "")
              : "") : "",
      providerDistrict:     provider is Map
          ? (provider["address"] is Map
              ? (provider["address"]["district"]?.toString() ?? "")
              : "") : "",
      providerPincode:      provider is Map
          ? (provider["address"] is Map
              ? (provider["address"]["pincode"]?.toString() ?? "")
              : "") : "",
      providerRating:       provider is Map && provider["rating"] is num
          ? (provider["rating"] as num).toDouble() : 0.0,
      providerTotalReviews: provider is Map && provider["totalReviews"] is num
          ? (provider["totalReviews"] as num).toInt() : 0,
    );
  }
}
