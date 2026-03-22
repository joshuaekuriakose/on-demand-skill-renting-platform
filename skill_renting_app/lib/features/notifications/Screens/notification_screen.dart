import 'package:flutter/material.dart';
import '../notification_service.dart';
import 'package:skill_renting_app/core/utils/notification_router.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List _items = [];
  bool _loading = true, _markingAll = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; });
    try {
      final d = await NotificationService.fetchNotifications();
      if (mounted) setState(() { _items = d; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _onTap(Map<String, dynamic> n) async {
    if (n["isRead"] != true) {
      NotificationService.markRead(n["_id"]);
      setState(() {
        final i = _items.indexWhere((x) => x["_id"] == n["_id"]);
        if (i != -1) { final m = Map<String, dynamic>.from(_items[i]); m["isRead"] = true; _items[i] = m; }
      });
    }
    NotificationRouter.navigate(
      navigatorState: Navigator.of(context),
      type: n["type"] as String?,
      data: n["bookingId"] != null ? {"bookingId": n["bookingId"].toString()} : null);
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    final ok = await NotificationService.markAllRead();
    if (!mounted) return;
    setState(() {
      _markingAll = false;
      if (ok) _items = _items.map((n) { final m = Map<String, dynamic>.from(n); m["isRead"] = true; return m; }).toList();
    });
  }

  int get _unreadCount => _items.where((n) => n["isRead"] == false).length;

  String _timeAgo(String? iso) {
    if (iso == null) return "";
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return "";
    final d = DateTime.now().difference(dt);
    if (d.inDays > 30) return "${(d.inDays / 30).floor()}mo ago";
    if (d.inDays > 0) return "${d.inDays}d ago";
    if (d.inHours > 0) return "${d.inHours}h ago";
    if (d.inMinutes > 0) return "${d.inMinutes}m ago";
    return "Just now";
  }

  _NotifStyle _styleFor(String? type) {
    switch (type) {
      case 'new_request':       return const _NotifStyle(Icons.assignment_ind_outlined, Color(0xFFFBBF24));
      case 'booking_accepted':  return const _NotifStyle(Icons.check_circle_outline_rounded, Color(0xFF34D399));
      case 'booking_rejected':  return const _NotifStyle(Icons.cancel_outlined, Color(0xFFF87171));
      case 'booking_completed': return const _NotifStyle(Icons.task_alt_rounded, Color(0xFF34D399));
      case 'begin_otp':         return const _NotifStyle(Icons.pin_outlined, Color(0xFF60A5FA));
      case 'complete_otp':      return const _NotifStyle(Icons.pin_outlined, Color(0xFFA78BFA));
      case 'service_started':   return const _NotifStyle(Icons.play_circle_outline_rounded, Color(0xFF60A5FA));
      case 'payment':           return const _NotifStyle(Icons.payments_outlined, Color(0xFF34D399));
      case 'no_response_warning': return const _NotifStyle(Icons.warning_amber_rounded, Color(0xFFFBBF24));
      case 'auto_cancelled':    return const _NotifStyle(Icons.cancel_rounded, Color(0xFFF87171));
      default:                  return const _NotifStyle(Icons.notifications_outlined, Color(0xFFA78BFA));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Text("Notifications", style: tt.titleLarge),
          if (_unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(10)),
              child: Text("$_unreadCount",
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
          ],
        ]),
        actions: [
          if (_unreadCount > 0)
            _markingAll
                ? const Padding(padding: EdgeInsets.all(14),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                : TextButton(onPressed: _markAllRead,
                    child: const Text("Mark all read", style: TextStyle(fontSize: 12))),
        ],
        shape: Border(bottom: BorderSide(
          color: isDark ? const Color(0xFF1E1C30) : cs.outlineVariant.withOpacity(0.5), width: 0.5)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.notifications_outlined, size: 56, color: cs.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text("No notifications", style: tt.bodySmall),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => Divider(height: 1,
                        color: isDark ? const Color(0xFF1E1C30) : cs.outlineVariant.withOpacity(0.4)),
                    itemBuilder: (_, i) {
                      final n    = Map<String, dynamic>.from(_items[i] as Map);
                      final read = n["isRead"] == true;
                      final s    = _styleFor(n["type"] as String?);
                      return InkWell(
                        onTap: () => _onTap(n),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          color: read ? Colors.transparent
                              : (isDark ? cs.primary.withOpacity(0.04) : cs.primaryContainer.withOpacity(0.2)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: s.color.withOpacity(read ? 0.06 : 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: s.color.withOpacity(read ? 0.1 : 0.25), width: 0.8)),
                              child: Icon(s.icon, size: 18, color: read ? cs.onSurfaceVariant : s.color)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(child: Text(n["title"] ?? "",
                                    style: tt.labelLarge?.copyWith(
                                        fontWeight: read ? FontWeight.w400 : FontWeight.w700))),
                                Text(_timeAgo(n["createdAt"]?.toString()),
                                    style: tt.labelSmall?.copyWith(
                                        color: read ? cs.onSurfaceVariant : s.color.withOpacity(0.8))),
                              ]),
                              const SizedBox(height: 3),
                              Text(n["message"] ?? "", style: tt.bodySmall, maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                            ])),
                            if (!read) ...[
                              const SizedBox(width: 8),
                              Container(width: 7, height: 7, margin: const EdgeInsets.only(top: 5),
                                decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                            ],
                          ]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _NotifStyle {
  final IconData icon;
  final Color color;
  const _NotifStyle(this.icon, this.color);
}
