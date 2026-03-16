class BookingModel {
  final String id;
  final String status;
  final String skillTitle;
  final String seekerName;
  final String providerName;
  final String seekerId;
  final String providerId;
  final String skillId;
  final String pricingUnit;
  final double price; // base price from pricingSnapshot.amount
  final bool isReviewed;
  final DateTime createdAt;
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, dynamic>? jobAddress;
  final double? distanceKmEstimate;
  final String? jobDescription;

  // GPS
  final double? jobGpsLat;
  final double? jobGpsLng;
  final String gpsLocationStatus; // pending | provided | skipped

  // Provider info (populated in seeker's /bookings/my)
  final Map<String, dynamic>? providerAddress;
  final double providerRating;
  final int providerTotalReviews;

  // OTP handshake (seeker sees OTP to share with provider)
  final String? beginOtp;
  final String? completeOtp;

  // Payment
  final double extraCharges;
  final double? totalAmount;
  final String paymentStatus; // pending | paid

  BookingModel({
    required this.id,
    required this.status,
    required this.skillTitle,
    required this.seekerName,
    required this.providerName,
    this.seekerId  = "",
    this.providerId = "",
    required this.skillId,
    required this.pricingUnit,
    required this.price,
    required this.isReviewed,
    required this.createdAt,
    required this.startDate,
    required this.endDate,
    this.jobAddress,
    this.distanceKmEstimate,
    this.jobDescription,
    this.jobGpsLat,
    this.jobGpsLng,
    this.gpsLocationStatus = "pending",
    this.providerAddress,
    this.providerRating = 0.0,
    this.providerTotalReviews = 0,
    this.beginOtp,
    this.completeOtp,
    this.extraCharges = 0,
    this.totalAmount,
    this.paymentStatus = "pending",
  });

  BookingModel copyWith({
    String? status,
    bool? isReviewed,
    String? gpsLocationStatus,
    String? beginOtp,
    String? completeOtp,
    double? extraCharges,
    double? totalAmount,
    String? paymentStatus,
  }) {
    return BookingModel(
      id: id,
      status: status ?? this.status,
      skillTitle: skillTitle,
      seekerName: seekerName,
      providerName: providerName,
      seekerId:   seekerId,
      providerId: providerId,
      skillId: skillId,
      pricingUnit: pricingUnit,
      price: price,
      isReviewed: isReviewed ?? this.isReviewed,
      createdAt: createdAt,
      startDate: startDate,
      endDate: endDate,
      jobAddress: jobAddress,
      distanceKmEstimate: distanceKmEstimate,
      jobDescription: jobDescription,
      jobGpsLat: jobGpsLat,
      jobGpsLng: jobGpsLng,
      gpsLocationStatus: gpsLocationStatus ?? this.gpsLocationStatus,
      providerAddress: providerAddress,
      providerRating: providerRating,
      providerTotalReviews: providerTotalReviews,
      beginOtp: beginOtp,
      completeOtp: completeOtp,
      extraCharges: extraCharges ?? this.extraCharges,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
    );
  }

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final skill    = json["skill"];
    final seeker   = json["seeker"];
    final provider = json["provider"];

    final rawStart = json["startDate"];
    final rawEnd   = json["endDate"];
    final parsedStart = rawStart != null
        ? DateTime.parse(rawStart).toLocal()
        : DateTime.parse(json["createdAt"]).toLocal();
    final parsedEnd = rawEnd != null
        ? DateTime.parse(rawEnd).toLocal()
        : parsedStart;

    final gpsRaw = json["jobGpsLocation"];
    final double? gpsLat = gpsRaw is Map ? (gpsRaw["lat"] as num?)?.toDouble() : null;
    final double? gpsLng = gpsRaw is Map ? (gpsRaw["lng"] as num?)?.toDouble() : null;

    final providerMap = provider is Map ? provider as Map<String, dynamic> : null;
    final Map<String, dynamic>? providerAddr = providerMap?["address"] is Map
        ? providerMap!["address"] as Map<String, dynamic>
        : null;
    final double providerRating = providerMap?["rating"] is num
        ? (providerMap!["rating"] as num).toDouble()
        : 0.0;
    final int providerTotalReviews = providerMap?["totalReviews"] is num
        ? (providerMap!["totalReviews"] as num).toInt()
        : 0;

    final pricingSnap = json["pricingSnapshot"];
    final double basePrice = pricingSnap is Map && pricingSnap["amount"] is num
        ? (pricingSnap["amount"] as num).toDouble()
        : 0.0;
    final String pricingUnit = skill is Map
        ? (skill["pricing"] is Map
            ? skill["pricing"]["unit"]?.toString() ?? "hour"
            : "hour")
        : (pricingSnap is Map ? pricingSnap["unit"]?.toString() ?? "hour" : "hour");

    return BookingModel(
      id: json["_id"] ?? "",
      status: json["status"] ?? "unknown",
      skillId:      skill is Map ? skill["_id"] ?? "" : "",
      skillTitle:   skill is Map ? skill["title"] ?? "Unknown" : "Unknown",
      pricingUnit:  pricingUnit,
      price:        basePrice,
      seekerName:   seeker is Map   ? seeker["name"]   ?? "Unknown" : "Unknown",
      providerName: providerMap != null ? providerMap["name"] ?? "Unknown" : "Unknown",
      seekerId:     seeker is Map   ? (seeker["_id"] ?? "").toString()   : "",
      providerId:   providerMap != null ? (providerMap["_id"] ?? "").toString() : "",
      isReviewed: json["isReviewed"] == true,
      createdAt: DateTime.parse(json["createdAt"]).toLocal(),
      startDate: parsedStart,
      endDate:   parsedEnd,
      jobAddress: json["jobAddress"] is Map<String, dynamic>
          ? json["jobAddress"] as Map<String, dynamic>
          : null,
      distanceKmEstimate: json["distanceKmEstimate"] is num
          ? (json["distanceKmEstimate"] as num).toDouble()
          : null,
      jobDescription: json["jobDescription"]?.toString(),
      jobGpsLat: gpsLat,
      jobGpsLng: gpsLng,
      gpsLocationStatus: json["gpsLocationStatus"]?.toString() ?? "pending",
      providerAddress:      providerAddr,
      providerRating:       providerRating,
      providerTotalReviews: providerTotalReviews,
      beginOtp:    json["beginOtp"]?.toString(),
      completeOtp: json["completeOtp"]?.toString(),
      extraCharges: json["extraCharges"] is num
          ? (json["extraCharges"] as num).toDouble()
          : 0.0,
      totalAmount: json["totalAmount"] is num
          ? (json["totalAmount"] as num).toDouble()
          : null,
      paymentStatus: json["paymentStatus"]?.toString() ?? "pending",
    );
  }

  // ── Getters ──────────────────────────────────────────────────────────────────

  bool get hasGps =>
      gpsLocationStatus == "provided" && jobGpsLat != null && jobGpsLng != null;

  String get createdAtFormatted {
    return "${createdAt.day.toString().padLeft(2, '0')}/"
        "${createdAt.month.toString().padLeft(2, '0')}/"
        "${createdAt.year}  "
        "${createdAt.hour.toString().padLeft(2, '0')}:"
        "${createdAt.minute.toString().padLeft(2, '0')}";
  }

  /// Slot display — hourly shows time range; day/week/month shows date range
  String get slotRangeFormatted {
    final s = startDate;
    final e = endDate;
    final dateStr =
        "${s.day.toString().padLeft(2, '0')}/${s.month.toString().padLeft(2, '0')}/${s.year}";

    if (pricingUnit == "hour") {
      final st =
          "${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}";
      final et =
          "${e.hour.toString().padLeft(2, '0')}:${e.minute.toString().padLeft(2, '0')}";
      return "$dateStr • $st - $et";
    }

    final endStr =
        "${e.day.toString().padLeft(2, '0')}/${e.month.toString().padLeft(2, '0')}/${e.year}";
    return "$dateStr to $endStr";
  }

  String get jobAddressFormatted {
    if (jobAddress == null) return "Address not provided";
    final parts = [
      jobAddress?["houseName"]?.toString() ?? "",
      jobAddress?["locality"]?.toString() ?? "",
      jobAddress?["district"]?.toString() ?? "",
      jobAddress?["pincode"]?.toString() ?? "",
    ].where((s) => s.trim().isNotEmpty).toList();
    return parts.isEmpty ? "Address not provided" : parts.join(", ");
  }

  /// District or locality — for compact card display
  String get jobDistrictLabel {
    if (jobAddress == null) return "Address unknown";
    final d = jobAddress?["district"]?.toString() ?? "";
    final l = jobAddress?["locality"]?.toString() ?? "";
    return d.isNotEmpty ? d : (l.isNotEmpty ? l : "Address unknown");
  }

  String get distanceLabel {
    if (distanceKmEstimate == null) return "Distance: unknown";
    return "Distance: ~${distanceKmEstimate!.toStringAsFixed(1)} km";
  }

  String get providerAddressFormatted {
    if (providerAddress == null) return "Not available";
    final parts = [
      providerAddress?["locality"]?.toString() ?? "",
      providerAddress?["district"]?.toString() ?? "",
    ].where((s) => s.trim().isNotEmpty).toList();
    return parts.isEmpty ? "Not available" : parts.join(", ");
  }

  /// Final amount due — totalAmount once confirmed, else base + extra
  double get amountDue => totalAmount ?? (price + extraCharges);
}
