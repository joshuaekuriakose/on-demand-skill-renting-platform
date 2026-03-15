import 'package:flutter/material.dart';
import '../notification_service.dart';
import 'package:skill_renting_app/features/common/widgets/skeleton_list.dart';
import 'package:skill_renting_app/core/utils/notification_router.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List _items = [];
  bool _loading = true;
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await NotificationService.fetchNotifications();
    if (mounted) setState(() { _items = data; _loading = false; });
  }

  /// Mark read locally then navigate to the right screen.
  Future<void> _onTap(Map<String, dynamic> n) async {
    if (n["isRead"] != true) {
      NotificationService.markRead(n["_id"]); // fire-and-forget
      setState(() {
        final i = _items.indexWhere((x) => x["_id"] == n["_id"]);
        if (i != -1) {
          final updated = Map<String, dynamic>.from(_items[i] as Map);
          updated["isRead"] = true;
          _items[i] = updated;
        }
      });
    }
    final type = n["type"] as String?;
    NotificationRouter.navigate(
      navigatorState: Navigator.of(context),
      type: type,
    );
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    final ok = await NotificationService.markAllRead();
    if (!mounted) return;
    setState(() {
      _markingAll = false;
      if (ok) {
        _items = _items.map((n) {
          final m = Map<String, dynamic>.from(n as Map);
          m["isRead"] = true;
          return m;
        }).toList();
      }
    });
  }

  int get _unreadCount => _items.where((n) => n["isRead"] == false).length;

  String _timeAgo(String? iso) {
    if (iso == null) return "";
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return "";
    final d = DateTime.now().difference(dt);
    if (d.inDays > 30) return "${(d.inDays / 30).floor()}mo ago";
    if (d.inDays > 0)  return "${d.inDays}d ago";
    if (d.inHours > 0) return "${d.inHours}h ago";
    if (d.inMinutes > 0) return "${d.inMinutes}m ago";
    return "Just now";
  }

  _NotifStyle _styleFor(String? type) {
    switch (type) {
      case 'new_request':       return _NotifStyle(Icons.assignment_ind,   Colors.orange);
      case 'booking_accepted':  return _NotifStyle(Icons.check_circle,     Colors.green);
      case 'booking_rejected':  return _NotifStyle(Icons.cancel,           Colors.red);
      case 'booking_completed': return _NotifStyle(Icons.task_alt,         Colors.teal);
      case 'begin_otp':         return _NotifStyle(Icons.pin,              Colors.indigo);
      case 'complete_otp':      return _NotifStyle(Icons.pin,              Colors.purple);
      case 'service_started':   return _NotifStyle(Icons.play_circle,      Colors.blue);
      case 'payment':           return _NotifStyle(Icons.payments,         const Color(0xFF2E7D32));
      default:                  return _NotifStyle(Icons.notifications,    Colors.indigo);
    }
  }

  String _actionLabel(String? type) {
    switch (type) {
      case 'new_request':       return 'View request →';
      case 'booking_accepted':  return 'View booking →';
      case 'booking_rejected':  return 'View booking →';
      case 'booking_completed': return 'View booking →';
      case 'begin_otp':         return 'View OTP →';
      case 'complete_otp':      return 'Verify completion →';
      case 'service_started':   return 'Track service →';
      case 'payment':           return 'View payment →';
      default:                  return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text("Notifications"),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10)),
                child: Text("$_unreadCount",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            _markingAll
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : TextButton.icon(
                    onPressed: _markAllRead,
                    icon: const Icon(Icons.done_all, size: 18),
                    label: const Text("Mark all read",
                        style: TextStyle(fontSize: 13)),
                  ),
        ],
      ),
      body: _loading
          ? const SkeletonList()
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text("No notifications",
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (context, index) {
                      final n =
                          Map<String, dynamic>.from(_items[index] as Map);
                      final isRead = n["isRead"] == true;
                      final type = n["type"] as String?;
                      final style = _styleFor(type);
                      final label = _actionLabel(type);

                      return InkWell(
                        onTap: () => _onTap(n),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          color: isRead ? Colors.white : Colors.indigo.shade50,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Type icon
                              Container(
                                width: 42, height: 42,
                                decoration: BoxDecoration(
                                  color: isRead
                                      ? Colors.grey.shade100
                                      : style.color.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(style.icon,
                                    size: 20,
                                    color: isRead ? Colors.grey : style.color),
                              ),
                              const SizedBox(width: 12),

                              // Text
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Expanded(
                                        child: Text(n["title"] ?? "",
                                            style: TextStyle(
                                                fontWeight: isRead
                                                    ? FontWeight.normal
                                                    : FontWeight.bold,
                                                fontSize: 14)),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(_timeAgo(n["createdAt"]),
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade400)),
                                    ]),
                                    const SizedBox(height: 4),
                                    Text(n["message"] ?? "",
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                            height: 1.4)),
                                    if (label.isNotEmpty) ...[
                                      const SizedBox(height: 5),
                                      Row(children: [
                                        Icon(Icons.arrow_forward_ios,
                                            size: 10,
                                            color:
                                                style.color.withOpacity(0.7)),
                                        const SizedBox(width: 3),
                                        Text(label,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: style.color
                                                    .withOpacity(0.8),
                                                fontWeight: FontWeight.w500)),
                                      ]),
                                    ],
                                  ],
                                ),
                              ),

                              // Unread dot
                              if (!isRead)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 6, top: 2),
                                  child: Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(
                                        color: style.color,
                                        shape: BoxShape.circle),
                                  ),
                                ),
                            ],
                          ),
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
