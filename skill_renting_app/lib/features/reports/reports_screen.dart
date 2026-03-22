import 'package:flutter/material.dart';
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
  List<dynamic> _mySkills = [];

  @override
  void initState() { super.initState(); _loadReports(); _loadSkills(); }

  Future<void> _loadReports() async {
    setState(() => _loading = true);
    final data = await ReportService.fetchMyReports();
    if (mounted) setState(() { _reports = data; _loading = false; });
  }

  Future<void> _loadSkills() async {
    final data = await SkillService.fetchMySkills();
    if (mounted) setState(() => _mySkills = data);
  }

  Future<void> _showRequestDialog() async {
    if (_mySkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You have no services added yet."))); return;
    }
    String? selectedSkillId = _mySkills[0]["_id"];
    DateTime? dateFrom, dateTo;
    bool submitting = false;

    await showDialog(
      context: context, barrierDismissible: false,
      builder: (dCtx) => StatefulBuilder(builder: (ctx, setS) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text("Generate Report"),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: selectedSkillId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: "Service"),
              items: _mySkills.map((s) => DropdownMenuItem<String>(
                value: s["_id"].toString(),
                child: Text(s["title"].toString(), overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (v) => setS(() => selectedSkillId = v),
            ),
            const SizedBox(height: 16),
            _DatePickTile("From", dateFrom, () async {
              final d = await showDatePicker(context: ctx,
                  initialDate: DateTime.now().subtract(const Duration(days: 7)),
                  firstDate: DateTime(2024), lastDate: DateTime.now());
              if (d != null) setS(() => dateFrom = d);
            }, cs),
            const SizedBox(height: 10),
            _DatePickTile("To", dateTo, () async {
              final d = await showDatePicker(context: ctx,
                  initialDate: DateTime.now(),
                  firstDate: dateFrom ?? DateTime(2024), lastDate: DateTime.now());
              if (d != null) setS(() => dateTo = d);
            }, cs),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text("Cancel")),
            FilledButton(
              onPressed: (submitting || selectedSkillId == null || dateFrom == null || dateTo == null) ? null : () async {
                setS(() => submitting = true);
                final result = await ReportService.generateCustomReport(
                  skillId: selectedSkillId!, dateFrom: dateFrom!, dateTo: dateTo!);
                Navigator.pop(dCtx);
                if (result.containsKey("empty")) {
                  _showEmptyDialog();
                } else if (result.containsKey("report")) {
                  _loadReports();
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Report generated successfully")));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result["error"] ?? "Failed")));
                }
              },
              child: submitting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("Generate"),
            ),
          ],
        );
      }),
    );
  }

  void _showEmptyDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text("No Activity"),
      content: const Text("No bookings found in the selected date range."),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
    ));
  }

  Future<void> _downloadReport(ReportModel report) async {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preparing PDF…"), duration: Duration(seconds: 30)));
    try {
      ReportModel full = report;
      if (report.data == null) {
        final fetched = await ReportService.fetchReportById(report.id);
        if (fetched == null || fetched.data == null) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Failed to load report data"))); return;
        }
        full = fetched;
      }
      final bytes = await ReportPdfBuilder.build(full);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await Printing.sharePdf(bytes: bytes,
          filename: "report_${full.skillTitle.replaceAll(' ','_')}.pdf");
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text("My Reports"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadReports),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRequestDialog,
        icon: const Icon(Icons.add_chart_rounded),
        label: const Text("New Report"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? _EmptyState(onTap: _showRequestDialog, cs: cs, tt: tt)
              : RefreshIndicator(
                  onRefresh: _loadReports,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _reports.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _ReportCard(
                        report: _reports[i],
                        onDownload: () => _downloadReport(_reports[i]),
                        cs: cs, tt: tt),
                  ),
                ),
    );
  }
}

// ─── Report card ──────────────────────────────────────────────────────────────
class _ReportCard extends StatefulWidget {
  final ReportModel report;
  final Future<void> Function() onDownload;
  final ColorScheme cs;
  final TextTheme tt;
  const _ReportCard({required this.report, required this.onDownload, required this.cs, required this.tt});
  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  bool _busy = false;

  Color get _typeColor {
    switch (widget.report.type) {
      case "auto_daily":   return const Color(0xFF3B82F6);
      case "auto_weekly":  return const Color(0xFF8B5CF6);
      case "auto_monthly": return const Color(0xFF4F46E5);
      case "custom":       return const Color(0xFF0D9488);
      default:             return Colors.grey;
    }
  }

  IconData get _typeIcon {
    switch (widget.report.type) {
      case "auto_daily":   return Icons.today_rounded;
      case "auto_weekly":  return Icons.view_week_rounded;
      case "auto_monthly": return Icons.calendar_month_rounded;
      case "custom":       return Icons.tune_rounded;
      default:             return Icons.description_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final tt = widget.tt;
    final r  = widget.report;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.8), width: 0.8),
        boxShadow: [BoxShadow(color: cs.shadow.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,2))],
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: _typeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _typeColor.withOpacity(0.25), width: 0.8),
          ),
          child: Icon(_typeIcon, color: _typeColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(r.typeLabel, style: tt.titleSmall)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _typeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _typeColor.withOpacity(0.25), width: 0.8),
              ),
              child: Text(r.skillTitle,
                  style: TextStyle(fontSize: 11, color: _typeColor, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 4),
          Text(r.periodLabel, style: tt.bodySmall),
          const SizedBox(height: 6),
          Row(children: [
            _Pill("${r.bookingCount} booking${r.bookingCount != 1 ? 's' : ''}", const Color(0xFF3B82F6)),
            const SizedBox(width: 6),
            _Pill("₹${r.totalAmount.toStringAsFixed(0)}", const Color(0xFF10B981)),
          ]),
        ])),
        const SizedBox(width: 10),
        Column(children: [
          _busy
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : GestureDetector(
                  onTap: () async {
                    setState(() => _busy = true);
                    await widget.onDownload();
                    if (mounted) setState(() => _busy = false);
                  },
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cs.primary.withOpacity(0.3), width: 0.8),
                    ),
                    child: Icon(Icons.download_rounded, size: 18, color: cs.primary),
                  ),
                ),
          const SizedBox(height: 4),
          Text("PDF", style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
        ]),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25), width: 0.8)),
    child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;
  const _EmptyState({required this.onTap, required this.cs, required this.tt});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 72, height: 72,
        decoration: BoxDecoration(color: cs.surfaceContainerHigh, shape: BoxShape.circle,
            border: Border.all(color: cs.outlineVariant, width: 0.8)),
        child: Icon(Icons.bar_chart_rounded, size: 32, color: cs.onSurfaceVariant)),
    const SizedBox(height: 16),
    Text("No reports yet", style: tt.titleMedium),
    const SizedBox(height: 6),
    Text("Generate one to track your earnings", style: tt.bodySmall, textAlign: TextAlign.center),
    const SizedBox(height: 20),
    FilledButton.icon(onPressed: onTap,
        icon: const Icon(Icons.add_chart_rounded, size: 16),
        label: const Text("Generate Report")),
  ]));
}

class _DatePickTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final ColorScheme cs;
  const _DatePickTile(this.label, this.date, this.onTap, this.cs);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: date != null ? cs.primaryContainer.withOpacity(0.4) : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: date != null ? cs.primary : cs.outlineVariant,
            width: date != null ? 1.5 : 0.8),
      ),
      child: Row(children: [
        Icon(Icons.calendar_today_rounded, size: 16,
            color: date != null ? cs.primary : cs.onSurfaceVariant),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          Text(date != null
              ? "${date!.day.toString().padLeft(2,'0')}/${date!.month.toString().padLeft(2,'0')}/${date!.year}"
              : "Tap to select",
              style: TextStyle(fontSize: 14, fontWeight: date != null ? FontWeight.w600 : FontWeight.normal,
                  color: date != null ? cs.primary : cs.onSurfaceVariant.withOpacity(0.5))),
        ]),
      ]),
    ),
  );
}
