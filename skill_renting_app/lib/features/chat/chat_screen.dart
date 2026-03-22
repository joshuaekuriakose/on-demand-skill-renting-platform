import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:skill_renting_app/core/services/auth_storage.dart';
import 'package:skill_renting_app/core/constants/api_constants.dart';
import 'message_service.dart';
import 'package:skill_renting_app/core/widgets/app_scaffold.dart';

// ── Chat modes ────────────────────────────────────────────────────────────────
// "booking"  → booking-based chat (bookingId required, conversationId ignored)
// "direct"   → seeker→provider direct chat
//              If conversationId is null this is a brand-new chat; conversationId
//              is obtained from the server after the first message is sent.

class ChatScreen extends StatefulWidget {
  // For booking chats
  final String? bookingId;

  // For direct chats
  final String? conversationId; // null if this is a new direct chat
  final String? providerId;     // required for new direct chats
  final String? skillId;        // optional context for new direct chats

  final String chatType;        // "booking" | "direct"
  final String otherPersonName;
  final String currentUserId;

  const ChatScreen({
    super.key,
    required this.otherPersonName,
    required this.currentUserId,
    this.chatType      = "booking",
    this.bookingId,
    this.conversationId,
    this.providerId,
    this.skillId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading  = true;
  bool _sending  = false;
  IO.Socket? _socket;

  // For direct chats: may be null until the first message is sent
  String? _conversationId;

  bool get _isDirect => widget.chatType == "direct";

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _loadMessages();
    _connectSocket();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    if (_isDirect && _conversationId != null) {
      _socket?.emit("leave_conversation", _conversationId);
    } else if (!_isDirect && widget.bookingId != null) {
      _socket?.emit("leave_booking", widget.bookingId);
    }
    _socket?.dispose();
    super.dispose();
  }

  // ── Load messages ─────────────────────────────────────────────────────────
  Future<void> _loadMessages() async {
    setState(() => _loading = true);

    List<Map<String, dynamic>> data = [];

    if (_isDirect && _conversationId != null) {
      data = await MessageService.fetchDirectMessages(_conversationId!);
    } else if (!_isDirect && widget.bookingId != null) {
      data = await MessageService.fetchMessages(widget.bookingId!);
    }
    // If direct chat with no conversationId yet, messages are empty (new chat)

    if (mounted) {
      setState(() { _messages = data; _loading = false; });
      _scrollToBottom();
    }
  }

  // ── Socket.io ─────────────────────────────────────────────────────────────
  Future<void> _connectSocket() async {
    final token = await AuthStorage.getToken();

    _socket = IO.io(
      ApiConstants.socketBaseUrl,
      IO.OptionBuilder()
          .setTransports(["websocket"])
          .setAuth(token != null ? {"token": token} : {})
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      if (_isDirect && _conversationId != null) {
        _socket!.emit("join_conversation", _conversationId);
      } else if (!_isDirect && widget.bookingId != null) {
        _socket!.emit("join_booking", widget.bookingId);
      }
    });

    _socket!.on("new_message", (data) {
      if (!mounted) return;
      final msg = Map<String, dynamic>.from(data as Map);

      final senderId = (msg["sender"] as Map?)?["_id"]?.toString() ?? "";
      if (senderId == widget.currentUserId) return;

      final id = msg["_id"]?.toString() ?? "";
      if (id.isNotEmpty && _messages.any((m) => m["_id"]?.toString() == id)) return;

      setState(() => _messages.add(msg));
      _scrollToBottom();
    });
  }

  // ── Join socket room once conversationId becomes known ────────────────────
  void _joinConversationRoom(String conversationId) {
    _socket?.emit("join_conversation", conversationId);
  }

  // ── Send ──────────────────────────────────────────────────────────────────
  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    _ctrl.clear();
    setState(() => _sending = true);

    // Optimistic insert
    final optimistic = <String, dynamic>{
      "_id":        "",
      "text":       text,
      "senderRole": "self",
      "sender":     {"_id": widget.currentUserId, "name": "You"},
      "createdAt":  DateTime.now().toIso8601String(),
      "_optimistic": true,
    };
    setState(() => _messages.add(optimistic));
    _scrollToBottom();

    Map<String, dynamic>? sent;

    if (_isDirect) {
      if (_conversationId == null) {
        // First message in a brand-new direct chat
        final result = await MessageService.startDirectChat(
          providerId: widget.providerId!,
          text:       text,
          skillId:    widget.skillId,
        );
        if (result != null) {
          final newConvId = result["conversationId"]?.toString();
          if (newConvId != null && mounted) {
            setState(() => _conversationId = newConvId);
            _joinConversationRoom(newConvId);
          }
          final msgData = result["message"];
          if (msgData is Map) {
            sent = Map<String, dynamic>.from(msgData);
          }
        }
      } else {
        // Subsequent messages in an existing direct chat
        sent = await MessageService.sendDirectMessage(_conversationId!, text);
      }
    } else {
      // Booking chat
      sent = await MessageService.sendMessage(widget.bookingId!, text);
    }

    if (mounted) {
      setState(() {
        _sending = false;
        final idx = _messages.lastIndexWhere((m) => m["_optimistic"] == true);
        if (idx != -1) {
          if (sent != null) {
            _messages[idx] = sent!;
          } else {
            _messages.removeAt(idx);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Failed to send message")),
            );
          }
        }
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _isMe(Map<String, dynamic> msg) {
    final senderId = (msg["sender"] as Map?)?["_id"]?.toString() ?? "";
    return senderId == widget.currentUserId || msg["_optimistic"] == true;
  }

  String _timeLabel(String? iso) {
    if (iso == null) return "";
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return "";
    return "${dt.hour.toString().padLeft(2, '0')}:"
        "${dt.minute.toString().padLeft(2, '0')}";
  }

  bool _showDateSeparator(int index) {
    if (index == 0) return true;
    final prev = DateTime.tryParse(
        _messages[index - 1]["createdAt"]?.toString() ?? "");
    final curr = DateTime.tryParse(
        _messages[index]["createdAt"]?.toString() ?? "");
    if (prev == null || curr == null) return false;
    return prev.day != curr.day ||
        prev.month != curr.month ||
        prev.year != curr.year;
  }

  String _dateSeparatorLabel(String? iso) {
    final dt = DateTime.tryParse(iso ?? "")?.toLocal();
    if (dt == null) return "";
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day)
      return "Today";
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day) return "Yesterday";
    return "${dt.day.toString().padLeft(2, '0')}/"
        "${dt.month.toString().padLeft(2, '0')}/"
        "${dt.year}";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        title: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.onPrimary.withOpacity(0.12),
            child: Text(
              widget.otherPersonName.isNotEmpty
                  ? widget.otherPersonName[0].toUpperCase()
                  : "?",
              style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.otherPersonName,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                if (_isDirect)
                  Text(
                    "Direct message",
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onPrimary.withOpacity(0.7),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 48,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(height: 10),
                            Text("No messages yet",
                                style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 15)),
                            const SizedBox(height: 6),
                            Text("Send the first message!",
                                style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final msg  = _messages[i];
                          final me   = _isMe(msg);
                          final text = msg["text"]?.toString() ?? "";
                          final time = _timeLabel(msg["createdAt"]?.toString());
                          final isPending = msg["_optimistic"] == true;

                          return Column(
                            children: [
                              if (_showDateSeparator(i))
                                _DateChip(_dateSeparatorLabel(
                                    msg["createdAt"]?.toString())),
                              Align(
                                alignment: me
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context)
                                              .size
                                              .width *
                                          0.72),
                                  decoration: BoxDecoration(
                                    color:
                                        me
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .surface,
                                    borderRadius: BorderRadius.only(
                                      topLeft:
                                          const Radius.circular(16),
                                      topRight:
                                          const Radius.circular(16),
                                      bottomLeft:
                                          Radius.circular(me ? 16 : 4),
                                      bottomRight:
                                          Radius.circular(me ? 4 : 16),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black
                                              .withOpacity(0.06),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2)),
                                    ],
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  child: Column(
                                    crossAxisAlignment: me
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      Text(text,
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: me
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .onPrimary
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurface,
                                              height: 1.4)),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(time,
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: me
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .onPrimary
                                                          .withOpacity(0.7)
                                                      : Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant)),
                                          if (me) ...[
                                            const SizedBox(width: 4),
                                            Icon(
                                              isPending
                                                  ? Icons.access_time
                                                  : Icons.done,
                                              size: 12,
                                              color: theme.colorScheme.onPrimary.withOpacity(0.7),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),

          // ── Input bar ──────────────────────────────────────────────────────
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: EdgeInsets.only(
              left: 12,
              right: 8,
              top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 10,
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: "Type a message…",
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            BorderSide(color: theme.colorScheme.outlineVariant)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            BorderSide(color: theme.colorScheme.outlineVariant)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                            color: theme.colorScheme.primary, width: 1.5)),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2)))
                    : FloatingActionButton.small(
                        onPressed: _send,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        elevation: 0,
                        child: Icon(
                          Icons.send_rounded,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 20,
                        ),
                      ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Date separator chip ───────────────────────────────────────────────────────
class _DateChip extends StatelessWidget {
  final String label;
  const _DateChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}
