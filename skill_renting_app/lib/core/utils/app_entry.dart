import 'package:flutter/material.dart';
import '../services/auth_storage.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/bookings/screens/seeker_dashboard.dart';
import '../../features/bookings/screens/provider_dashboard.dart';
import '../../features/dashboard/main_dashboard.dart'; 

class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _decideStart(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data as Widget;
      },
    );
  }

  Future<Widget> _decideStart() async {
  final token = await AuthStorage.getToken();

  if (token == null) {
    return const LoginScreen();
  }

  // Everyone goes to MainDashboard regardless of role
  return const MainDashboard();
}
}
