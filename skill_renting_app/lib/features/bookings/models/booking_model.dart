class BookingModel {
  final String id;
  final String status;
  final String skillTitle;
  final String seekerName;
  final String providerName;
  final String skillId;
  final String pricingUnit;
  final bool isReviewed;
  final DateTime createdAt;
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, dynamic>? jobAddress;
  final double? distanceKmEstimate;
  final String? jobDescription; // ← NEW

  // GPS
  final double? jobGpsLat;
  final double? jobGpsLng;
  final String gpsLocationStatus; // "pending" | "provided" | "skipped"

  BookingModel({
    required this.id,
    required this.status,
    required this.skillTitle,
    required this.seekerName,
    required this.providerName,
    required this.skillId,
    required this.pricingUnit,
    required this.isReviewed,
    required this.createdAt,
    required this.startDate,
    required this.endDate,
    this.jobAddress,
    this.distanceKmEstimate,
    this.jobDescription,
    this.jobGpsLat,
    this.jobGpsLng,
    this.gpsLocationStatus = 'pending',
  });

  bool get hasGps =>
      gpsLocationStatus == 'provided' &&
      jobGpsLat != null &&
      jobGpsLng != null;

  BookingModel copyWith({
    String? status,
    bool? isReviewed,
    double? jobGpsLat,
    double? jobGpsLng,
    String? gpsLocationStatus,
  }) {
    return BookingModel(
      id: id,
      status: status ?? this.status,
      skillTitle: skillTitle,
      seekerName: seekerName,
      providerName: providerName,
      skillId: skillId,
      pricingUnit: pricingUnit,
      isReviewed: isReviewed ?? this.isReviewed,
      createdAt: createdAt,
      startDate: startDate,
      endDate: endDate,
      jobAddress: jobAddress,
      distanceKmEstimate: distanceKmEstimate,
      jobDescription: jobDescription,
      jobGpsLat: jobGpsLat ?? this.jobGpsLat,
      jobGpsLng: jobGpsLng ?? this.jobGpsLng,
      gpsLocationStatus: gpsLocationStatus ?? this.gpsLocationStatus,
    );
  }

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final skill = json["skill"];
    final seeker = json["seeker"];
    final provider = json["provider"];

    final rawStart = json["startDate"];
    final rawEnd = json["endDate"];
    final parsedStart = rawStart != null
        ? DateTime.parse(rawStart)
        : DateTime.parse(json["createdAt"]);
    final parsedEnd = rawEnd != null ? DateTime.parse(rawEnd) : parsedStart;

    double? gpsLat;
    double? gpsLng;
    final gpsRaw = json["jobGpsLocation"];
    if (gpsRaw is Map) {
      gpsLat = (gpsRaw["lat"] as num?)?.toDouble();
      gpsLng = (gpsRaw["lng"] as num?)?.toDouble();
    }

    return BookingModel(
      id: json["_id"] ?? "",
      status: json["status"] ?? "unknown",
      skillId: skill is Map ? skill["_id"] ?? "" : "",
      skillTitle: skill is Map
          ? skill["title"] ?? "Unknown Skill"
          : "Unknown Skill",
      pricingUnit: skill is Map
          ? (skill["pricing"] is Map
              ? skill["pricing"]["unit"]?.toString() ?? "hour"
              : "hour")
          : "hour",
      seekerName: seeker is Map ? seeker["name"] ?? "Unknown" : "Unknown",
      providerName:
          provider is Map ? provider["name"] ?? "Unknown" : "Unknown",
      isReviewed: json["isReviewed"] == true,
      createdAt: DateTime.parse(json["createdAt"]),
      startDate: parsedStart,
      endDate: parsedEnd,
      jobAddress: json["jobAddress"] is Map<String, dynamic>
          ? json["jobAddress"] as Map<String, dynamic>
          : null,
      distanceKmEstimate: json["distanceKmEstimate"] is num
          ? (json["distanceKmEstimate"] as num).toDouble()
          : null,
      jobDescription: json["jobDescription"]?.toString(),
      jobGpsLat: gpsLat,
      jobGpsLng: gpsLng,
      gpsLocationStatus:
          json["gpsLocationStatus"]?.toString() ?? "pending",
    );
  }

  // ── Formatted getters ────────────────────────────────────────────────────

  String get createdAtFormatted {
    final local = createdAt.toLocal();
    return "${local.day}/${local.month}/${local.year} "
        "${local.hour}:${local.minute.toString().padLeft(2, '0')}";
  }

  String get slotRangeFormatted {
    final localStart = startDate.toLocal();
    final localEnd = endDate.toLocal();

    String fmtDate(DateTime d) =>
        "${d.day.toString().padLeft(2, '0')}/"
        "${d.month.toString().padLeft(2, '0')}/"
        "${d.year}";

    String fmtTime(DateTime d) =>
        "${d.hour.toString().padLeft(2, '0')}:"
        "${d.minute.toString().padLeft(2, '0')}";

    if (pricingUnit == "day" ||
        pricingUnit == "week" ||
        pricingUnit == "month") {
      final s = fmtDate(localStart);
      final e = fmtDate(localEnd);
      return s == e ? s : "$s to $e";
    }

    return "${fmtDate(localStart)} • ${fmtTime(localStart)} - ${fmtTime(localEnd)}";
  }

  String get jobAddressFormatted {
    if (jobAddress == null) return "Address not provided";
    final house = jobAddress?["houseName"]?.toString() ?? "";
    final loc = jobAddress?["locality"]?.toString() ?? "";
    final dist = jobAddress?["district"]?.toString() ?? "";
    final pin = jobAddress?["pincode"]?.toString() ?? "";
    final parts =
        [house, loc, dist, pin].where((s) => s.trim().isNotEmpty).toList();
    return parts.isEmpty ? "Address not provided" : parts.join(", ");
  }

  /// Just the district / town for compact display
  String get jobDistrictLabel {
    if (jobAddress == null) return "Location not set";
    final dist = jobAddress?["district"]?.toString() ?? "";
    final loc = jobAddress?["locality"]?.toString() ?? "";
    if (dist.isNotEmpty) return dist;
    if (loc.isNotEmpty) return loc;
    return "Location not set";
  }

  String get distanceLabel {
    if (distanceKmEstimate == null) return "Distance: unknown";
    return "Distance: ~${distanceKmEstimate!.toStringAsFixed(1)} km";
  }
}
