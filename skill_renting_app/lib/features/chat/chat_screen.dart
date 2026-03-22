import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:skill_renting_app/core/services/auth_storage.dart';
import 'package:skill_renting_app/core/constants/api_constants.dart';
import 'message_service.dart';

class ChatScreen extends StatefulWidget {
  final String? bookingId;
  final String? conversationId;
  final String? providerId;
  final String? skillId;
  final String chatType;
  final String otherPersonName;
  final String currentUserId;

  const ChatScreen({
    super.key,
    required this.otherPersonName,
    required this.currentUserId,
    this.chatType = "booking",
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
  bool _loading = false, _sending = false;
  IO.Socket? _socket;
  String? _conversationId;
  bool get _isDirect => widget.chatType == "direct";

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    _loadMessages(); _connectSocket();
  }

  @override
  void dispose() {
    _ctrl.dispose(); _scroll.dispose();
    if (_isDirect && _conversationId != null)
      _socket?.emit("leave_conversation", _conversationId);
    else if (!_isDirect && widget.bookingId != null)
      _socket?.emit("leave_booking", widget.bookingId);
    _socket?.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    List<Map<String, dynamic>> data = [];
    if (_isDirect && _conversationId != null)
      data = await MessageService.fetchDirectMessages(_conversationId!);
    else if (!_isDirect && widget.bookingId != null)
      data = await MessageService.fetchMessages(widget.bookingId!);
    if (mounted) { setState(() { _messages = data; _loading = false; }); _scrollToBottom(); }
  }

  Future<void> _connectSocket() async {
    final token = await AuthStorage.getToken();
    _socket = IO.io(ApiConstants.socketBaseUrl,
      IO.OptionBuilder().setTransports(["websocket"])
          .setAuth(token != null ? {"token": token} : {}).disableAutoConnect().build());
    _socket!.connect();
    _socket!.onConnect((_) {
      if (_isDirect && _conversationId != null) _socket!.emit("join_conversation", _conversationId);
      else if (!_isDirect && widget.bookingId != null) _socket!.emit("join_booking", widget.bookingId);
    });
    _socket!.on("new_message", (data) {
      if (!mounted) return;
      final msg = Map<String, dynamic>.from(data as Map);
      final sid = (msg["sender"] as Map?)?["_id"]?.toString() ?? "";
      if (sid == widget.currentUserId) return;
      final id = msg["_id"]?.toString() ?? "";
      if (id.isNotEmpty && _messages.any((m) => m["_id"]?.toString() == id)) return;
      setState(() => _messages.add(msg)); _scrollToBottom();
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    _ctrl.clear();
    setState(() => _sending = true);
    final opt = <String, dynamic>{
      "_id": "", "text": text, "senderRole": "self",
      "sender": {"_id": widget.currentUserId, "name": "You"},
      "createdAt": DateTime.now().toIso8601String(), "_optimistic": true,
    };
    setState(() => _messages.add(opt)); _scrollToBottom();
    Map<String, dynamic>? sent;
    if (_isDirect) {
      if (_conversationId == null) {
        final res = await MessageService.startDirectChat(
            providerId: widget.providerId!, text: text, skillId: widget.skillId);
        if (res != null) {
          final cid = res["conversationId"]?.toString();
          if (cid != null && mounted) { setState(() => _conversationId = cid); _socket?.emit("join_conversation", cid); }
          if (res["message"] is Map) sent = Map<String, dynamic>.from(res["message"]);
        }
      } else {
        sent = await MessageService.sendDirectMessage(_conversationId!, text);
      }
    } else {
      sent = await MessageService.sendMessage(widget.bookingId!, text);
    }
    if (mounted) setState(() {
      _sending = false;
      final i = _messages.lastIndexWhere((m) => m["_optimistic"] == true);
      if (i != -1) { if (sent != null) _messages[i] = sent!; else _messages.removeAt(i); }
    });
  }

  void _scrollToBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  });

  bool _isMe(Map m) =>
      (m["sender"] as Map?)?["_id"]?.toString() == widget.currentUserId || m["_optimistic"] == true;

  String _time(String? iso) {
    if (iso == null) return "";
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return "";
    return "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";
  }

  bool _showDateSep(int i) {
    if (i == 0) return true;
    final p = DateTime.tryParse(_messages[i-1]["createdAt"]?.toString() ?? "");
    final c = DateTime.tryParse(_messages[i]["createdAt"]?.toString() ?? "");
    if (p == null || c == null) return false;
    return p.day != c.day || p.month != c.month || p.year != c.year;
  }

  String _dateSepLabel(String? iso) {
    final dt = DateTime.tryParse(iso ?? "")?.toLocal();
    if (dt == null) return "";
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) return "Today";
    final y = now.subtract(const Duration(days: 1));
    if (dt.year == y.year && dt.month == y.month && dt.day == y.day) return "Yesterday";
    return "${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}";
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
        shape: Border(bottom: BorderSide(
          color: isDark ? const Color(0xFF1E1C30) : cs.outlineVariant.withOpacity(0.5), width: 0.5)),
        title: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [cs.primary, cs.secondary]),
              shape: BoxShape.circle),
            child: Center(child: Text(
              widget.otherPersonName.isNotEmpty ? widget.otherPersonName[0].toUpperCase() : "?",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.otherPersonName, style: tt.titleSmall),
            if (_isDirect) Text("Direct message",
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ])),
        ]),
      ),
      body: Column(children: [
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 44, color: cs.onSurfaceVariant),
                  const SizedBox(height: 10),
                  Text("Send the first message", style: tt.bodySmall),
                ]))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) {
                    final msg  = _messages[i];
                    final me   = _isMe(msg);
                    final pend = msg["_optimistic"] == true;
                    return Column(children: [
                      if (_showDateSep(i))
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cs.outlineVariant.withOpacity(0.4), width: 0.5)),
                          child: Text(_dateSepLabel(msg["createdAt"]?.toString()),
                              style: tt.labelSmall)),
                      Align(
                        alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                          decoration: BoxDecoration(
                            color: me ? cs.primary
                                : (isDark ? const Color(0xFF161427) : cs.surfaceContainerHigh),
                            borderRadius: BorderRadius.only(
                              topLeft:     const Radius.circular(16),
                              topRight:    const Radius.circular(16),
                              bottomLeft:  Radius.circular(me ? 16 : 4),
                              bottomRight: Radius.circular(me ? 4 : 16)),
                            border: me ? null : Border.all(
                              color: isDark ? const Color(0xFF2A2740) : cs.outlineVariant.withOpacity(0.5),
                              width: 0.6)),
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                          child: Column(crossAxisAlignment: me ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                            Text(msg["text"] ?? "",
                                style: TextStyle(
                                    fontSize: 14, height: 1.4,
                                    color: me ? Colors.white
                                        : cs.onSurface)),
                            const SizedBox(height: 3),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(_time(msg["createdAt"]?.toString()),
                                  style: TextStyle(fontSize: 10,
                                      color: me ? Colors.white54 : cs.onSurfaceVariant)),
                              if (me) ...[const SizedBox(width: 3),
                                Icon(pend ? Icons.access_time_rounded : Icons.done_rounded,
                                    size: 11, color: Colors.white54)],
                            ]),
                          ]),
                        ),
                      ),
                    ]);
                  },
                )),

        // Input bar
        Container(
          color: isDark ? const Color(0xFF0F0E17) : cs.surface,
          padding: EdgeInsets.only(
              left: 12, right: 8, top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 10),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(
              color: isDark ? const Color(0xFF1E1C30) : cs.outlineVariant.withOpacity(0.5),
              width: 0.5))),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _ctrl, maxLines: 4, minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: cs.onSurface, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Message…",
                filled: true,
                fillColor: isDark ? const Color(0xFF161427) : cs.surfaceContainerHigh,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF2A2740) : cs.outlineVariant, width: 0.8)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF2A2740) : cs.outlineVariant, width: 0.8)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: cs.primary, width: 1.2))),
              onSubmitted: (_) => _send())),
            const SizedBox(width: 8),
            _sending
                ? Padding(padding: const EdgeInsets.all(10),
                    child: SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)))
                : GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                          color: cs.primary, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.send_rounded, size: 18, color: Colors.white))),
          ]),
        ),
      ]),
    );
  }
}
