import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'report_model.dart';
import 'report_service.dart';
import 'report_pdf_builder.dart';
import 'package:skill_renting_app/features/skills/skill_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<ReportModel> _reports = [];
  bool _loading = true;

  // For custom report request
  List<dynamic> _mySkills = [];
  bool _loadingSkills = false;

  @override
  void initState() {
    super.initState();
    _loadReports();
    _loadSkills();
  }

  Future<void> _loadReports() async {
    setState(() => _loading = true);
    final data = await ReportService.fetchMyReports();
    if (mounted) setState(() { _reports = data; _loading = false; });
  }

  Future<void> _loadSkills() async {
    setState(() => _loadingSkills = true);
    final data = await SkillService.fetchMySkills();
    if (mounted) setState(() { _mySkills = data; _loadingSkills = false; });
  }

  // ── Custom report request dialog ────────────────────────────────────────────
  Future<void> _showRequestDialog() async {
    if (_mySkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You have no services added yet.")),
      );
      return;
    }

    String? selectedSkillId = _mySkills[0]["_id"];
    DateTime? dateFrom;
    DateTime? dateTo;
    bool submitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Request Report",
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Select Service",
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedSkillId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200)),
                  ),
                  items: _mySkills
                      .map((s) => DropdownMenuItem<String>(
                            value: s["_id"].toString(),
                            child: Text(s["title"].toString(),
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) => setDState(() => selectedSkillId = v),
                ),

                const SizedBox(height: 16),
                const Text("Date Range",
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 6),

                Row(children: [
                  Expanded(
                    child: _DatePickerTile(
                      label: "From",
                      date: dateFrom,
                      onPick: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now()
                              .subtract(const Duration(days: 7)),
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setDState(() => dateFrom = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DatePickerTile(
                      label: "To",
                      date: dateTo,
                      onPick: () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now(),
                          firstDate: dateFrom ?? DateTime(2024),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setDState(() => dateTo = d);
                      },
                    ),
                  ),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dCtx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (selectedSkillId == null ||
                          dateFrom == null ||
                          dateTo == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  "Please select a service and date range")),
                        );
                        return;
                      }
                      setDState(() => submitting = true);

                      final result =
                          await ReportService.generateCustomReport(
                        skillId:  selectedSkillId!,
                        dateFrom: dateFrom!,
                        dateTo:   dateTo!,
                      );

                      Navigator.pop(dCtx);

                      if (result.containsKey("empty")) {
                        _showEmptyDialog();
                      } else if (result.containsKey("report")) {
                        _loadReports();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Report generated successfully!")),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  result["error"] ?? "Failed to generate report")),
                        );
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text("Generate"),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmptyDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text("No Activity",
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              "You don't have any activity since your last report in the selected date range.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // ── PDF download/share ──────────────────────────────────────────────────────
  Future<void> _downloadReport(ReportModel report) async {
    // Show loading snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Row(children: [
            SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text("Preparing report…"),
          ]),
          duration: Duration(seconds: 30)),
    );

    try {
      // Fetch full data if not already loaded
      ReportModel full = report;
      if (report.data == null) {
        final fetched = await ReportService.fetchReportById(report.id);
        if (fetched == null || fetched.data == null) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to load report data")),
          );
          return;
        }
        full = fetched;
      }

      final bytes = await ReportPdfBuilder.build(full);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Use printing package — shows share/save/print sheet
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            "report_${full.skillTitle.replaceAll(' ', '_')}_${full.dateFrom.year}${full.dateFrom.month.toString().padLeft(2, '0')}${full.dateFrom.day.toString().padLeft(2, '0')}.pdf",
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Reports"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRequestDialog,
        icon: const Icon(Icons.add_chart),
        label: const Text("Request Report"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadReports,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _reports.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) =>
                        _ReportCard(
                          report: _reports[i],
                          onDownload: () => _downloadReport(_reports[i]),
                        ),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No reports yet",
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            "Scheduled reports are generated automatically.\nOr tap the button below to request one.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showRequestDialog,
            icon: const Icon(Icons.add_chart),
            label: const Text("Request Report"),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Report card
// ─────────────────────────────────────────────────────────────────────────────

class _ReportCard extends StatefulWidget {
  final ReportModel report;
  final Future<void> Function() onDownload;
  const _ReportCard({required this.report, required this.onDownload});

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _busy = false;

  Color get _typeColor {
    switch (widget.report.type) {
      case "auto_daily":   return Colors.blue;
      case "auto_weekly":  return Colors.purple;
      case "auto_monthly": return Colors.indigo;
      case "custom":       return Colors.teal;
      default:             return Colors.grey;
    }
  }

  IconData get _typeIcon {
    switch (widget.report.type) {
      case "auto_daily":   return Icons.today;
      case "auto_weekly":  return Icons.view_week;
      case "auto_monthly": return Icons.calendar_month;
      case "custom":       return Icons.tune;
      default:             return Icons.description;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Type icon
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _typeColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_typeIcon, color: _typeColor, size: 24),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(r.typeLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: _typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(r.skillTitle,
                          style: TextStyle(
                              fontSize: 11,
                              color: _typeColor,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(r.periodLabel,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(height: 6),
                  Row(children: [
                    _InfoPill(
                        "${r.bookingCount} booking${r.bookingCount != 1 ? 's' : ''}",
                        Colors.blue),
                    const SizedBox(width: 6),
                    _InfoPill(
                        "₹${r.totalAmount.toStringAsFixed(0)} received",
                        Colors.green),
                  ]),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Download button
            Column(
              children: [
                _busy
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : IconButton(
                        onPressed: () async {
                          setState(() => _busy = true);
                          await widget.onDownload();
                          if (mounted) setState(() => _busy = false);
                        },
                        icon: const Icon(Icons.download_rounded),
                        color: Colors.indigo,
                        tooltip: "Download PDF",
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.indigo.shade50,
                        ),
                      ),
                Text("PDF",
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade400)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String text;
  final Color color;
  const _InfoPill(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500)),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onPick;
  const _DatePickerTile(
      {required this.label, required this.date, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: date != null
                  ? Colors.indigo.shade200
                  : Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            Text(
              date != null
                  ? "${date!.day.toString().padLeft(2, '0')}/${date!.month.toString().padLeft(2, '0')}/${date!.year}"
                  : "Tap to pick",
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: date != null
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: date != null
                      ? Colors.indigo.shade700
                      : Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}
