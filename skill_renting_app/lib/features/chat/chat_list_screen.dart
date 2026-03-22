import 'package:flutter/material.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';
import 'message_service.dart';
import 'chat_screen.dart';
import 'package:skill_renting_app/core/widgets/app_scaffold.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;
  String _myId  = "";
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    setState(() => _errorMessage = null);
    _myId = await AuthStorage.getUserId();
    try {
      final data = await MessageService.getChatList();
      if (mounted) setState(() {
        _chats = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  String _timeLabel(String? iso) {
    if (iso == null) return "";
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return "";
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.day == yesterday.day && dt.month == yesterday.month) return "Yesterday";
    return "${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}";
  }

  Color _statusColor(String s) {
    switch (s) {
      case "accepted":    return Colors.blue;
      case "in_progress": return Colors.purple;
      case "completed":   return Colors.green;
      case "direct":      return Colors.teal;
      default:            return Colors.grey;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case "in_progress": return "in progress";
      case "direct":      return "direct";
      default:            return s;
    }
  }

  void _openChat(Map<String, dynamic> c) async {
    final chatType  = c["chatType"]?.toString() ?? "booking";
    final chatId    = c["chatId"]?.toString()   ?? "";
    final name      = c["otherPersonName"]?.toString() ?? "User";

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatType:       chatType,
          bookingId:      chatType == "booking" ? chatId : null,
          conversationId: chatType == "direct"  ? chatId : null,
          otherPersonName: name,
          currentUserId:  _myId,
        ),
      ),
    );
    _load(); // refresh unread counts after returning
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      appBar: AppBar(
        title: const Text("Messages",
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            color: theme.colorScheme.error),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(onPressed: _load, child: const Text("Retry")),
                      ],
                    ),
                  ),
                )
              : _chats.isEmpty
                  ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 14),
                      Text("No messages yet",
                          style: TextStyle(
                              fontSize: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Text(
                        "Message a provider from their skill page,\nor start chatting after a booking is accepted.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _chats.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: theme.dividerColor),
                    itemBuilder: (_, i) {
                      final c      = _chats[i];
                      final unread = (c["unreadCount"] as num?)?.toInt() ?? 0;
                      final latest = c["latestMessage"] as Map?;
                      final name   = c["otherPersonName"]?.toString() ?? "User";
                      final skill  = c["skillTitle"]?.toString() ?? "";
                      final status = c["status"]?.toString() ?? "";
                      final isDirect = c["chatType"]?.toString() == "direct";

                      return InkWell(
                        onTap: () => _openChat(c),
                        child: Container(
                          color: unread > 0
                              ? theme.colorScheme.primaryContainer.withOpacity(0.35)
                              : theme.colorScheme.surface,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              // Avatar
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: isDirect
                                        ? theme.colorScheme.secondaryContainer
                                        : theme.colorScheme.primaryContainer,
                                    child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : "?",
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isDirect
                                              ? theme.colorScheme.onSecondaryContainer
                                              : theme.colorScheme.onPrimaryContainer),
                                    ),
                                  ),
                                  if (unread > 0)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 18, height: 18,
                                        decoration: const BoxDecoration(
                                            color: Color(0xFF3949AB),
                                            shape: BoxShape.circle),
                                        child: Center(
                                          child: Text(
                                            unread > 9 ? "9+" : "$unread",
                                            style: TextStyle(
                                                color: theme.colorScheme.onPrimary,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 14),

                              // Content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Expanded(
                                        child: Text(name,
                                            style: TextStyle(
                                                fontWeight: unread > 0
                                                    ? FontWeight.bold
                                                    : FontWeight.w600,
                                                fontSize: 14)),
                                      ),
                                      if (latest != null)
                                        Text(
                                          _timeLabel(latest["createdAt"]
                                              ?.toString()),
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: unread > 0
                                                  ? theme.colorScheme.primary
                                                  : theme.colorScheme.onSurfaceVariant,
                                              fontWeight: unread > 0
                                                  ? FontWeight.bold
                                                  : FontWeight.normal),
                                        ),
                                    ]),
                                    const SizedBox(height: 3),
                                    if (skill.isNotEmpty)
                                      Text(skill,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: theme.colorScheme.onSurfaceVariant)),
                                    const SizedBox(height: 3),
                                    Row(children: [
                                      Expanded(
                                        child: Text(
                                          latest?["text"]?.toString() ?? "",
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: unread > 0
                                                      ? theme.colorScheme.onSurface
                                                      : theme.colorScheme.onSurfaceVariant,
                                              fontWeight: unread > 0
                                                  ? FontWeight.w500
                                                  : FontWeight.normal),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Status chip
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _statusColor(status)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          _statusLabel(status),
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: _statusColor(status),
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ]),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.chevron_right,
                                  color: theme.colorScheme.onSurfaceVariant, size: 18),
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
