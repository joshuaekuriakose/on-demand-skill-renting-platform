import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:skill_renting_app/core/services/auth_storage.dart';
import 'package:skill_renting_app/core/constants/api_constants.dart';
import 'message_service.dart';

class ChatScreen extends StatefulWidget {
  final String bookingId;
  final String otherPersonName; // shown in app bar
  final String currentUserId;

  const ChatScreen({
    super.key,
    required this.bookingId,
    required this.otherPersonName,
    required this.currentUserId,
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

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _connectSocket();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _socket?.emit("leave_booking", widget.bookingId);
    _socket?.dispose();
    super.dispose();
  }

  // ── REST: initial load ────────────────────────────────────────────────────
  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    final data = await MessageService.fetchMessages(widget.bookingId);
    if (mounted) {
      setState(() { _messages = data; _loading = false; });
      _scrollToBottom();
    }
  }

  // ── Socket.io: real-time ──────────────────────────────────────────────────
  void _connectSocket() {
    // Strip "/api" suffix — socket connects to root
    final baseUrl = ApiConstants.baseUrl.replaceAll("/api", "");

    _socket = IO.io(baseUrl, IO.OptionBuilder()
        .setTransports(["websocket"])
        .disableAutoConnect()
        .build());

    _socket!.connect();

    _socket!.onConnect((_) {
      _socket!.emit("join_booking", widget.bookingId);
    });

    _socket!.on("new_message", (data) {
      if (!mounted) return;
      final msg = Map<String, dynamic>.from(data as Map);

      // Skip messages sent by ME — already handled by optimistic insert + REST replace
      final senderId = (msg["sender"] as Map?)?["_id"]?.toString() ?? "";
      if (senderId == widget.currentUserId) return;

      // Avoid genuine duplicates from reconnect/reload
      final id = msg["_id"]?.toString() ?? "";
      if (id.isNotEmpty &&
          _messages.any((m) => m["_id"]?.toString() == id)) return;

      setState(() => _messages.add(msg));
      _scrollToBottom();
    });
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

    final sent = await MessageService.sendMessage(widget.bookingId, text);
    if (mounted) {
      setState(() {
        _sending = false;
        // Replace optimistic with real message
        final idx = _messages.lastIndexWhere((m) => m["_optimistic"] == true);
        if (idx != -1) {
          if (sent != null) {
            _messages[idx] = sent;
          } else {
            _messages.removeAt(idx); // send failed
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
    return senderId == widget.currentUserId ||
        msg["_optimistic"] == true;
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
    if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day) return "Today";
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
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        title: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Text(
              widget.otherPersonName.isNotEmpty
                  ? widget.otherPersonName[0].toUpperCase()
                  : "?",
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.otherPersonName,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                const Text("Booking Chat",
                    style:
                        TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ),
        ]),
      ),
      body: Column(
        children: [
          // ── Message list ────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 56,
                                color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text("No messages yet",
                                style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 15)),
                            const SizedBox(height: 6),
                            Text("Send the first message!",
                                style: TextStyle(
                                    color: Colors.grey.shade300,
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
                          final time = _timeLabel(
                              msg["createdAt"]?.toString());
                          final isPending =
                              msg["_optimistic"] == true;

                          return Column(
                            children: [
                              // Date separator
                              if (_showDateSeparator(i))
                                _DateChip(_dateSeparatorLabel(
                                    msg["createdAt"]?.toString())),

                              // Bubble
                              Align(
                                alignment: me
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(
                                      bottom: 6),
                                  constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context)
                                              .size
                                              .width *
                                          0.72),
                                  decoration: BoxDecoration(
                                    color: me
                                        ? Colors.indigo
                                        : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft:
                                          const Radius.circular(16),
                                      topRight:
                                          const Radius.circular(16),
                                      bottomLeft: Radius.circular(
                                          me ? 16 : 4),
                                      bottomRight: Radius.circular(
                                          me ? 4 : 16),
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
                                                  ? Colors.white
                                                  : Colors
                                                      .black87,
                                              height: 1.4)),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize:
                                            MainAxisSize.min,
                                        children: [
                                          Text(time,
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: me
                                                      ? Colors
                                                          .white60
                                                      : Colors.grey
                                                          .shade400)),
                                          if (me) ...[
                                            const SizedBox(
                                                width: 4),
                                            Icon(
                                              isPending
                                                  ? Icons.access_time
                                                  : Icons.done,
                                              size: 12,
                                              color: Colors.white60,
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

          // ── Input bar ────────────────────────────────────────────────────
          Container(
            color: Colors.white,
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
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide:
                            BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                            color: Colors.indigo, width: 1.5)),
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
                        backgroundColor: Colors.indigo,
                        elevation: 0,
                        child: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}
