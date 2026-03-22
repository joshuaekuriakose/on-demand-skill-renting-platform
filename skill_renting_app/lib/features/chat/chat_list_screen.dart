import 'package:flutter/material.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';
import 'message_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;
  String _myId = "";
  String? _errorMessage;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _errorMessage = null; });
    _myId = await AuthStorage.getUserId();
    try {
      final data = await MessageService.getChatList();
      if (mounted) setState(() { _chats = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _errorMessage = e.toString(); _loading = false; });
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
    return "${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}";
  }

  Color _statusColor(String s, ColorScheme cs) {
    switch (s) {
      case "accepted":    return const Color(0xFF3B82F6);
      case "in_progress": return const Color(0xFF8B5CF6);
      case "completed":   return const Color(0xFF10B981);
      case "direct":      return cs.primary;
      default:            return cs.onSurfaceVariant;
    }
  }

  void _openChat(Map<String, dynamic> c) async {
    final chatType = c["chatType"]?.toString() ?? "booking";
    final chatId   = c["chatId"]?.toString()   ?? "";
    final name     = c["otherPersonName"]?.toString() ?? "User";
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
      chatType:       chatType,
      bookingId:      chatType == "booking" ? chatId : null,
      conversationId: chatType == "direct"  ? chatId : null,
      otherPersonName: name,
      currentUserId:  _myId,
    )));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(title: const Text("Messages")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.error_outline, color: cs.error, size: 48),
                    const SizedBox(height: 12),
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton(onPressed: _load, child: const Text("Retry")),
                  ]),
                ))
              : _chats.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh,
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.outlineVariant, width: 0.8),
                        ),
                        child: Icon(Icons.chat_bubble_outline_rounded, size: 32, color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      Text("No conversations yet", style: tt.titleMedium),
                      const SizedBox(height: 6),
                      Text("Message a provider from their service page",
                          style: tt.bodySmall, textAlign: TextAlign.center),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _chats.length,
                        separatorBuilder: (_, __) => Divider(
                            height: 1, indent: 72,
                            color: cs.outlineVariant.withOpacity(0.5)),
                        itemBuilder: (_, i) {
                          final c      = _chats[i];
                          final unread = (c["unreadCount"] as num?)?.toInt() ?? 0;
                          final latest = c["latestMessage"] as Map?;
                          final name   = c["otherPersonName"]?.toString() ?? "User";
                          final skill  = c["skillTitle"]?.toString() ?? "";
                          final status = c["status"]?.toString() ?? "";
                          final isDirect = c["chatType"]?.toString() == "direct";
                          final statusCol = _statusColor(status, cs);

                          return InkWell(
                            onTap: () => _openChat(c),
                            child: Container(
                              color: unread > 0
                                  ? cs.primaryContainer.withOpacity(0.15)
                                  : Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(children: [
                                // Avatar
                                Stack(children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: isDirect
                                        ? cs.secondaryContainer
                                        : cs.primaryContainer,
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : "?",
                                      style: TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold,
                                        color: isDirect ? cs.onSecondaryContainer : cs.onPrimaryContainer),
                                    ),
                                  ),
                                  if (unread > 0)
                                    Positioned(right: 0, bottom: 0,
                                      child: Container(
                                        width: 18, height: 18,
                                        decoration: BoxDecoration(
                                            color: cs.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: cs.surfaceContainerLowest, width: 1.5)),
                                        child: Center(child: Text(
                                          unread > 9 ? "9+" : "$unread",
                                          style: TextStyle(color: cs.onPrimary, fontSize: 9, fontWeight: FontWeight.bold),
                                        )),
                                      ),
                                    ),
                                ]),
                                const SizedBox(width: 12),

                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Expanded(child: Text(name,
                                        style: tt.titleSmall?.copyWith(
                                            fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600))),
                                    if (latest != null)
                                      Text(_timeLabel(latest["createdAt"]?.toString()),
                                          style: tt.labelSmall?.copyWith(
                                              color: unread > 0 ? cs.primary : cs.onSurfaceVariant,
                                              fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal)),
                                  ]),
                                  const SizedBox(height: 2),
                                  if (skill.isNotEmpty)
                                    Text(skill, style: tt.labelSmall?.copyWith(color: cs.primary)),
                                  const SizedBox(height: 2),
                                  Row(children: [
                                    Expanded(child: Text(
                                      latest?["text"]?.toString() ?? "",
                                      style: tt.bodySmall?.copyWith(
                                          color: unread > 0 ? cs.onSurface : cs.onSurfaceVariant,
                                          fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal),
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                    )),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusCol.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: statusCol.withOpacity(0.25), width: 0.8),
                                      ),
                                      child: Text(
                                        status == "in_progress" ? "in progress" : status,
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: statusCol),
                                      ),
                                    ),
                                  ]),
                                ])),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
