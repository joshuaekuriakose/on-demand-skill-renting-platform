import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'report_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// All characters used here are ASCII-safe (Helvetica/Times compatible).
// No Rs. sign ₹  → "Rs."
// No star glyphs → "(4/5)"
// No ellipsis …  → "..."
// No bullet •    → "|"
// No tick ✓      → "[PAID]"
// ─────────────────────────────────────────────────────────────────────────────

class ReportPdfBuilder {
  // ── Palette ───────────────────────────────────────────────────────────────
  static const _primary   = PdfColor.fromInt(0xFF3F51B5); // indigo
  static const _surface   = PdfColor.fromInt(0xFFF8F8F8);
  static const _accent    = PdfColor.fromInt(0xFF388E3C); // dark green
  static const _warn      = PdfColor.fromInt(0xFFE65100); // deep orange
  static const _red       = PdfColor.fromInt(0xFFC62828);
  static const _greyLight = PdfColor.fromInt(0xFFE0E0E0);
  static const _greyMid   = PdfColor.fromInt(0xFF9E9E9E);
  static const _black     = PdfColor.fromInt(0xFF212121);
  static const _white     = PdfColors.white;

  static Future<Uint8List> build(ReportModel report) async {
    final data = report.data!;
    final pdf  = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    );

    // ── Cover page ────────────────────────────────────────────────────────────
    pdf.addPage(_coverPage(report, data));

    // ── Booking detail pages (MultiPage — auto-flows across pages) ────────────
    if (data.bookings.isNotEmpty) {
      pdf.addPage(_bookingMultiPage(report, data));
    }

    // ── Off/Rest slots page ───────────────────────────────────────────────────
    if (data.blockedSlots.isNotEmpty) {
      pdf.addPage(_offSlotsPage(report, data));
    }

    return pdf.save();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGE 1 — Cover
  // ═══════════════════════════════════════════════════════════════════════════
  static pw.Page _coverPage(ReportModel report, ReportData data) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      build: (ctx) {
        final received  = data.totalReceived;
        final pending   = _pendingAmount(data);
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Banner ──────────────────────────────────────────────────────
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.fromLTRB(36, 32, 36, 28),
              decoration: const pw.BoxDecoration(color: _primary),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("SKILL RENTING APP",
                      style: pw.TextStyle(
                          fontSize: 9,
                          color: _white,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 2.5)),
                  pw.SizedBox(height: 6),
                  pw.Text(report.typeLabel.toUpperCase(),
                      style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: _white)),
                  pw.SizedBox(height: 4),
                  pw.Text(report.periodLabel,
                      style: const pw.TextStyle(
                          fontSize: 13, color: _white)),
                ],
              ),
            ),

            pw.SizedBox(height: 28),

            // ── Info cards row ───────────────────────────────────────────────
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 36),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: _infoCard("PROVIDER", [
                    _kv("Name",  data.providerName),
                    _kv("Phone", data.providerPhone),
                  ])),
                  pw.SizedBox(width: 14),
                  pw.Expanded(child: _infoCard("SERVICE", [
                    _kv("Skill",   data.skillTitle),
                    _kv("Level",   _capFirst(data.skillLevel)),
                    _kv("Rate",    "Rs. ${data.pricePerUnit.toStringAsFixed(0)} / ${data.pricingUnit}"),
                  ])),
                  pw.SizedBox(width: 14),
                  pw.Expanded(child: _infoCard("REPORT PERIOD", [
                    _kv("From",      _fmtDate(data.dateFrom)),
                    _kv("To",        _fmtDate(data.dateTo)),
                    _kv("Generated", _fmtDate(report.generatedAt)),
                  ])),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // ── Summary stats ────────────────────────────────────────────────
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 36),
              child: pw.Row(children: [
                _statTile("TOTAL BOOKINGS",  "${data.bookings.length}", _primary),
                pw.SizedBox(width: 12),
                _statTile("RECEIVED",        "Rs. ${received.toStringAsFixed(0)}", _accent),
                pw.SizedBox(width: 12),
                _statTile("PENDING",         "Rs. ${pending.toStringAsFixed(0)}", _warn),
                pw.SizedBox(width: 12),
                _statTile("OFF SLOTS",       "${data.blockedSlots.length}", _greyMid),
              ]),
            ),

            pw.SizedBox(height: 28),

            // ── Divider + footer note ────────────────────────────────────────
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 36),
              child: pw.Divider(color: _greyLight, thickness: 0.8),
            ),
            pw.SizedBox(height: 8),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 36),
              child: pw.Text(
                "This report was automatically generated by Skill Renting App. "
                "All amounts in Indian Rupees (Rs.).",
                style: const pw.TextStyle(fontSize: 8, color: _greyMid),
              ),
            ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGES 2+ — Booking details (MultiPage — landscape for wider table)
  // ═══════════════════════════════════════════════════════════════════════════
  static pw.MultiPage _bookingMultiPage(ReportModel report, ReportData data) {
    // Column widths — landscape A4 gives ~780pt usable width
    const colWidths = {
      0: pw.FlexColumnWidth(2.4), // Customer + phone
      1: pw.FlexColumnWidth(1.8), // Location
      2: pw.FlexColumnWidth(2.6), // Description
      3: pw.FlexColumnWidth(2.0), // Date & Slot
      4: pw.FlexColumnWidth(1.4), // Job Status
      5: pw.FlexColumnWidth(2.2), // Fee
      6: pw.FlexColumnWidth(1.4), // Payment
      7: pw.FlexColumnWidth(2.0), // Review
    };

    final headerStyle = pw.TextStyle(
        fontSize: 8, fontWeight: pw.FontWeight.bold, color: _white);
    final cellStyle    = pw.TextStyle(fontSize: 7.5, color: _black);
    final smallGrey    = pw.TextStyle(fontSize: 7, color: _greyMid);

    // Build table header row (repeated on each page via MultiPage header)
    pw.Widget buildTableHeader() => pw.Table(
          columnWidths: colWidths,
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _primary),
              children: [
                "Customer",
                "Location",
                "Description",
                "Date & Slot",
                "Status",
                "Fee (Rs.)",
                "Payment",
                "Rating",
              ].map((h) => _hCell(h, headerStyle)).toList(),
            ),
          ],
        );

    // Build data rows table
    pw.Widget buildDataRows() {
      final rows = data.bookings.asMap().entries.map((entry) {
        final i = entry.key;
        final b = entry.value;
        final bg = i.isEven ? _white : _surface;

        // ── Status label ──────────────────────────────────────────────────
        final statusLabel = _jobStatusLabel(b.status);
        final statusColor = _jobStatusColor(b.status);

        // ── Fee cell content ──────────────────────────────────────────────
        String feeText;
        pw.TextStyle feeStyle;
        if (b.status == "rejected") {
          feeText  = "NIL";
          feeStyle = pw.TextStyle(fontSize: 7.5, color: _red, fontWeight: pw.FontWeight.bold);
        } else if (b.status == "accepted" || b.status == "in_progress") {
          feeText  = "Not Calculated";
          feeStyle = pw.TextStyle(fontSize: 7.5, color: _greyMid);
        } else {
          // completed
          feeText = "Base: Rs. ${b.fee.toStringAsFixed(0)}/${b.feeUnit}";
          if (b.extraCharges > 0) {
            feeText += "\nExtra: Rs. ${b.extraCharges.toStringAsFixed(0)}";
          }
          feeText += "\nTotal: Rs. ${b.totalAmount.toStringAsFixed(0)}";
          feeStyle = pw.TextStyle(fontSize: 7.5, color: _black);
        }

        // ── Payment cell ──────────────────────────────────────────────────
        String payText;
        pw.TextStyle payStyle;
        if (b.status == "rejected") {
          payText  = "-";
          payStyle = pw.TextStyle(fontSize: 7.5, color: _greyMid);
        } else if (b.status == "accepted" || b.status == "in_progress") {
          payText  = "Pending";
          payStyle = pw.TextStyle(fontSize: 7.5, color: _warn, fontWeight: pw.FontWeight.bold);
        } else if (b.paymentStatus == "paid") {
          payText  = "Received";
          payStyle = pw.TextStyle(fontSize: 7.5, color: _accent, fontWeight: pw.FontWeight.bold);
        } else {
          payText  = "Pending";
          payStyle = pw.TextStyle(fontSize: 7.5, color: _warn, fontWeight: pw.FontWeight.bold);
        }

        // ── Rating cell ───────────────────────────────────────────────────
        final review = b.review;
        String reviewText;
        if (review == null) {
          reviewText = "No Rating";
        } else {
          // ASCII stars: "*** --" style (safe for Helvetica)
          final stars = List.generate(5, (i) => i < review.rating ? "*" : "-").join();
          reviewText = "$stars  ${review.rating}/5";
          if (review.comment.isNotEmpty) {
            final c = review.comment.length > 45
                ? "${review.comment.substring(0, 45)}..."
                : review.comment;
            reviewText += "\n$c";
          }
        }

        // ── Slot cell ─────────────────────────────────────────────────────
        final slotWidget = _slotCell(b, cellStyle, smallGrey);

        return pw.TableRow(
          decoration: pw.BoxDecoration(color: bg),
          children: [
            // Customer + phone
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(5, 6, 5, 6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(b.seekerName,
                      style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: _black)),
                  pw.SizedBox(height: 2),
                  pw.Text(b.seekerPhone, style: smallGrey),
                ],
              ),
            ),
            // Location
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(5, 6, 5, 6),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(b.locality, style: cellStyle),
                  pw.Text(b.district, style: smallGrey),
                ],
              ),
            ),
            // Description
            _dCell(
              b.description.length > 70
                  ? "${b.description.substring(0, 70)}..."
                  : b.description,
              cellStyle,
            ),
            // Date & Slot
            slotWidget,
            // Job status badge
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(5, 6, 5, 6),
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 4, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: _jobStatusBg(b.status),
                  borderRadius: pw.BorderRadius.circular(3),
                  border: pw.Border.all(color: statusColor, width: 0.5),
                ),
                child: pw.Text(statusLabel,
                    style: pw.TextStyle(
                        fontSize: 7,
                        color: statusColor,
                        fontWeight: pw.FontWeight.bold)),
              ),
            ),
            // Fee
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(5, 6, 5, 6),
              child: pw.Text(feeText, style: feeStyle),
            ),
            // Payment
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(5, 6, 5, 6),
              child: pw.Text(payText, style: payStyle),
            ),
            // Rating
            _dCell(reviewText, cellStyle),
          ],
        );
      }).toList();

      return pw.Table(
        columnWidths: colWidths,
        border: pw.TableBorder.all(color: _greyLight, width: 0.4),
        children: rows,
      );
    }

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 32),

      // ── Repeated page header ─────────────────────────────────────────────
      header: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("BOOKING DETAILS",
                      style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: _primary)),
                  pw.Text(
                    "${data.skillTitle}  |  ${data.providerName}  |  ${report.periodLabel}",
                    style: const pw.TextStyle(
                        fontSize: 8, color: _greyMid),
                  ),
                ],
              ),
              pw.Text(
                "Page ${ctx.pageNumber} of ${ctx.pagesCount}",
                style: const pw.TextStyle(fontSize: 8, color: _greyMid),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          buildTableHeader(),
        ],
      ),

      // ── Footer ───────────────────────────────────────────────────────────
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          "Skill Renting App  |  Confidential",
          style: const pw.TextStyle(fontSize: 7, color: _greyMid),
        ),
      ),

      // ── Content ──────────────────────────────────────────────────────────
      build: (ctx) => [
        buildDataRows(),
        pw.SizedBox(height: 16),
        // Total received — shown once after all rows
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 18, vertical: 10),
            decoration: pw.BoxDecoration(
              color: _accent,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              "TOTAL RECEIVED:  Rs. ${data.totalReceived.toStringAsFixed(0)}",
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: _white),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Off / Rest slots page
  // ═══════════════════════════════════════════════════════════════════════════
  static pw.Page _offSlotsPage(ReportModel report, ReportData data) {
    const cellStyle = pw.TextStyle(fontSize: 8);
    final headerStyle = pw.TextStyle(
        fontSize: 9, fontWeight: pw.FontWeight.bold, color: _white);

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Banner
          pw.Container(
            width: double.infinity,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const pw.BoxDecoration(color: _primary),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("OFF / REST SLOTS",
                        style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: _white)),
                    pw.Text(
                      "${data.skillTitle}  |  ${data.providerName}",
                      style:
                          const pw.TextStyle(fontSize: 9, color: _white),
                    ),
                  ],
                ),
                pw.Text(report.periodLabel,
                    style: const pw.TextStyle(fontSize: 9, color: _white)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          pw.Table(
            border: pw.TableBorder.all(color: _greyLight, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(4),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _primary),
                children: ["From", "To", "Reason"]
                    .map((h) => _hCell(h, headerStyle))
                    .toList(),
              ),
              ...data.blockedSlots.asMap().entries.map((e) {
                final bg = e.key.isEven ? _white : _surface;
                final bl = e.value;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    _dCell(_fmtDt(bl.startDate), cellStyle),
                    _dCell(_fmtDt(bl.endDate),   cellStyle),
                    _dCell(bl.reason,             cellStyle),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 12),
          pw.Text(
            "Note: Lunch hour slots (12:30) are system-excluded and not listed here.",
            style: const pw.TextStyle(fontSize: 8, color: _greyMid),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════════════════════════════════════

  static double _pendingAmount(ReportData d) => d.bookings
      .where((b) => b.status == "completed" && b.paymentStatus != "paid")
      .fold(0.0, (s, b) => s + b.totalAmount);

  static String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/"
      "${d.month.toString().padLeft(2, '0')}/"
      "${d.year}";

  static String _fmtDt(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/"
      "${d.month.toString().padLeft(2, '0')}/"
      "${d.year}  "
      "${d.hour.toString().padLeft(2, '0')}:"
      "${d.minute.toString().padLeft(2, '0')}";

  static String _capFirst(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String _jobStatusLabel(String status) {
    switch (status) {
      case "accepted":    return "Accepted";
      case "in_progress": return "In Progress";
      case "completed":   return "Completed";
      case "rejected":    return "Rejected";
      case "cancelled":   return "Cancelled";
      default:            return _capFirst(status);
    }
  }

  static PdfColor _jobStatusBg(String status) {
    switch (status) {
      case "accepted":    return const PdfColor.fromInt(0xFFE3F2FD); // light blue
      case "in_progress": return const PdfColor.fromInt(0xFFF3E5F5); // light purple
      case "completed":   return const PdfColor.fromInt(0xFFE8F5E9); // light green
      case "rejected":    return const PdfColor.fromInt(0xFFFFEBEE); // light red
      case "cancelled":   return const PdfColor.fromInt(0xFFF5F5F5); // light grey
      default:            return const PdfColor.fromInt(0xFFF5F5F5);
    }
  }

  static PdfColor _jobStatusColor(String status) {
    switch (status) {
      case "accepted":    return const PdfColor.fromInt(0xFF1565C0); // blue
      case "in_progress": return const PdfColor.fromInt(0xFF6A1B9A); // purple
      case "completed":   return const PdfColor.fromInt(0xFF2E7D32); // green
      case "rejected":    return const PdfColor.fromInt(0xFFC62828); // red
      case "cancelled":   return const PdfColor.fromInt(0xFF757575); // grey
      default:            return _greyMid;
    }
  }

  // Slot cell — date on line 1, time range on line 2
  static pw.Widget _slotCell(
      ReportBookingRow b, pw.TextStyle base, pw.TextStyle small) {
    final dateLine = _fmtDate(b.startDate);
    String timeLine;
    if (b.feeUnit == "hour") {
      final s = "${b.startDate.hour.toString().padLeft(2, '0')}:"
          "${b.startDate.minute.toString().padLeft(2, '0')}";
      final e = "${b.endDate.hour.toString().padLeft(2, '0')}:"
          "${b.endDate.minute.toString().padLeft(2, '0')}";
      timeLine = "$s - $e";
    } else {
      final endDate = _fmtDate(b.endDate);
      timeLine = "to $endDate";
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.fromLTRB(5, 6, 5, 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(dateLine, style: pw.TextStyle(
              fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: _black)),
          pw.SizedBox(height: 2),
          pw.Text(timeLine, style: small),
        ],
      ),
    );
  }

  // Header cell
  static pw.Widget _hCell(String text, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.fromLTRB(6, 7, 6, 7),
      child: pw.Text(text, style: style),
    );
  }

  // Data cell
  static pw.Widget _dCell(String text, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.fromLTRB(5, 6, 5, 6),
      child: pw.Text(text, style: style),
    );
  }

  // Info card (cover page)
  static pw.Widget _infoCard(String title, List<pw.Widget> rows) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF5F5F5),
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: _greyLight, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: _primary,
                  letterSpacing: 1.2)),
          pw.SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  static pw.Widget _kv(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 7.5, color: _greyMid)),
          pw.SizedBox(height: 1),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: _black)),
        ],
      ),
    );
  }

  static pw.Widget _statTile(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 7, color: _white, letterSpacing: 0.8)),
            pw.SizedBox(height: 5),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _white)),
          ],
        ),
      ),
    );
  }
}
