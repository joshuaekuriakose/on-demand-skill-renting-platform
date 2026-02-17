import 'package:flutter/material.dart';
import '../notification_service.dart';
import 'package:skill_renting_app/features/common/widgets/skeleton_list.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await NotificationService.fetchNotifications();

    setState(() {
      _items = data;
      _loading = false;
    });
  }

  Future<void> _read(String id) async {
    await NotificationService.markRead(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
      ),

      body: _loading
  ? const SkeletonList()

          : _items.isEmpty
              ? const Center(child: Text("No notifications"))

              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final n = _items[index];

                    return ListTile(
                      title: Text(n["title"]),
                      subtitle: Text(n["message"]),

                      trailing: n["isRead"]
                          ? null
                          : const Icon(Icons.circle,
                              color: Colors.blue, size: 10),

                      onTap: () {
                        _read(n["_id"]);
                      },
                    );
                  },
                ),
    );
  }
}
