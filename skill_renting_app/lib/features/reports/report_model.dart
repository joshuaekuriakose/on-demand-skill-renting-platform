class ReportModel {
  final String id;
  final String skillId;
  final String skillTitle;
  final String type; // auto_daily | auto_weekly | auto_monthly | custom
  final DateTime dateFrom;
  final DateTime dateTo;
  final int bookingCount;
  final double totalAmount;
  final DateTime generatedAt;
  final ReportData? data; // null in list view, populated in detail view

  ReportModel({
    required this.id,
    required this.skillId,
    required this.skillTitle,
    required this.type,
    required this.dateFrom,
    required this.dateTo,
    required this.bookingCount,
    required this.totalAmount,
    required this.generatedAt,
    this.data,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    final skill = json["skill"];
    return ReportModel(
      id:           json["_id"] ?? "",
      skillId:      skill is Map ? skill["_id"] ?? "" : json["skill"]?.toString() ?? "",
      skillTitle:   skill is Map ? skill["title"] ?? "" : "",
      type:         json["type"] ?? "custom",
      dateFrom:     DateTime.parse(json["dateFrom"]).toLocal(),
      dateTo:       DateTime.parse(json["dateTo"]).toLocal(),
      bookingCount: (json["bookingCount"] as num?)?.toInt() ?? 0,
      totalAmount:  (json["totalAmount"] as num?)?.toDouble() ?? 0,
      generatedAt:  DateTime.parse(json["generatedAt"] ?? json["createdAt"]).toLocal(),
      data: json["reportData"] != null
          ? ReportData.fromJson(Map<String, dynamic>.from(json["reportData"]))
          : null,
    );
  }

  String get typeLabel {
    switch (type) {
      case "auto_daily":   return "Daily Report";
      case "auto_weekly":  return "Weekly Report";
      case "auto_monthly": return "Monthly Report";
      case "custom":       return "Custom Report";
      default:             return "Report";
    }
  }

  String get periodLabel {
    final f = _fmt(dateFrom);
    final t = _fmt(dateTo);
    return f == t ? f : "$f – $t";
  }

  String _fmt(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
}

// ── Full report data (used for PDF generation) ────────────────────────────────

class ReportData {
  final String providerName;
  final String providerPhone;
  final String skillTitle;
  final String skillLevel;
  final String pricingUnit;
  final double pricePerUnit;
  final DateTime dateFrom;
  final DateTime dateTo;
  final List<ReportBookingRow> bookings;
  final List<ReportBlockedSlot> blockedSlots;
  final double totalReceived;

  ReportData({
    required this.providerName,
    required this.providerPhone,
    required this.skillTitle,
    required this.skillLevel,
    required this.pricingUnit,
    required this.pricePerUnit,
    required this.dateFrom,
    required this.dateTo,
    required this.bookings,
    required this.blockedSlots,
    required this.totalReceived,
  });

  factory ReportData.fromJson(Map<String, dynamic> j) {
    return ReportData(
      providerName:  j["providerName"]  ?? "",
      providerPhone: j["providerPhone"] ?? "",
      skillTitle:    j["skillTitle"]    ?? "",
      skillLevel:    j["skillLevel"]    ?? "",
      pricingUnit:   j["pricingUnit"]   ?? "hour",
      pricePerUnit:  (j["pricePerUnit"] as num?)?.toDouble() ?? 0,
      dateFrom:      DateTime.parse(j["dateFrom"].toString()).toLocal(),
      dateTo:        DateTime.parse(j["dateTo"].toString()).toLocal(),
      bookings:      (j["bookings"] as List? ?? [])
          .map((b) => ReportBookingRow.fromJson(Map<String, dynamic>.from(b)))
          .toList(),
      blockedSlots: (j["blockedSlots"] as List? ?? [])
          .map((b) => ReportBlockedSlot.fromJson(Map<String, dynamic>.from(b)))
          .toList(),
      totalReceived: (j["totalReceived"] as num?)?.toDouble() ?? 0,
    );
  }
}

class ReportBookingRow {
  final String bookingId;
  final String seekerName;
  final String seekerPhone;
  final String locality;
  final String district;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final double fee;
  final String feeUnit;
  final double extraCharges;
  final double totalAmount;
  final String paymentStatus;
  final ReportReview? review;

  ReportBookingRow({
    required this.bookingId,
    required this.seekerName,
    required this.seekerPhone,
    required this.locality,
    required this.district,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.fee,
    required this.feeUnit,
    required this.extraCharges,
    required this.totalAmount,
    required this.paymentStatus,
    this.review,
  });

  factory ReportBookingRow.fromJson(Map<String, dynamic> j) {
    return ReportBookingRow(
      bookingId:     j["bookingId"]     ?? "",
      seekerName:    j["seekerName"]    ?? "N/A",
      seekerPhone:   j["seekerPhone"]   ?? "N/A",
      locality:      j["locality"]      ?? "N/A",
      district:      j["district"]      ?? "N/A",
      description:   j["description"]   ?? "",
      startDate:     DateTime.parse(j["startDate"].toString()).toLocal(),
      endDate:       DateTime.parse(j["endDate"].toString()).toLocal(),
      status:        j["status"]        ?? "",
      fee:           (j["fee"] as num?)?.toDouble() ?? 0,
      feeUnit:       j["feeUnit"]       ?? "—",
      extraCharges:  (j["extraCharges"] as num?)?.toDouble() ?? 0,
      totalAmount:   (j["totalAmount"]  as num?)?.toDouble() ?? 0,
      paymentStatus: j["paymentStatus"] ?? "pending",
      review: j["review"] != null
          ? ReportReview.fromJson(Map<String, dynamic>.from(j["review"]))
          : null,
    );
  }

  String get slotLabel {
    final d = "${startDate.day.toString().padLeft(2, '0')}/"
        "${startDate.month.toString().padLeft(2, '0')}/"
        "${startDate.year}";
    if (feeUnit == "hour") {
      final s = "${startDate.hour.toString().padLeft(2, '0')}:"
          "${startDate.minute.toString().padLeft(2, '0')}";
      final e = "${endDate.hour.toString().padLeft(2, '0')}:"
          "${endDate.minute.toString().padLeft(2, '0')}";
      return "$d  $s – $e";
    }
    final e = "${endDate.day.toString().padLeft(2, '0')}/"
        "${endDate.month.toString().padLeft(2, '0')}/"
        "${endDate.year}";
    return "$d to $e";
  }
}

class ReportReview {
  final int rating;
  final String comment;
  ReportReview({required this.rating, required this.comment});
  factory ReportReview.fromJson(Map<String, dynamic> j) =>
      ReportReview(
        rating:  (j["rating"] as num?)?.toInt() ?? 0,
        comment: j["comment"] ?? "",
      );
}

class ReportBlockedSlot {
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  ReportBlockedSlot({required this.startDate, required this.endDate, required this.reason});
  factory ReportBlockedSlot.fromJson(Map<String, dynamic> j) =>
      ReportBlockedSlot(
        startDate: DateTime.parse(j["startDate"].toString()).toLocal(),
        endDate:   DateTime.parse(j["endDate"].toString()).toLocal(),
        reason:    j["reason"] ?? "Off",
      );
}
