import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'core/utils/app_entry.dart';
import 'package:skill_renting_app/features/auth/screens/login_screen.dart';
import 'package:skill_renting_app/features/auth/screens/register_screen.dart';
import 'package:skill_renting_app/features/notifications/screens/notification_screen.dart';
import 'package:skill_renting_app/core/utils/notification_router.dart';

// ── Global navigator key ──────────────────────────────────────────────────────
// Lets us navigate from outside the widget tree (e.g. notification tap handler)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ── Local notifications plugin (singleton) ────────────────────────────────────
final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

// ── Android notification channel ─────────────────────────────────────────────
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'skill_renting_high', // id — must match AndroidManifest meta-data
  'Skill Renting Alerts',
  description: 'Booking and service notifications',
  importance: Importance.max,
  playSound: true,
);

// ── Background message handler (top-level, NOT inside a class) ───────────────
// Called when app is in background/terminated and a data-only message arrives.
// For messages WITH a notification payload FCM shows the system tray entry
// automatically — this handler is for any extra work (e.g. local DB updates).
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Nothing extra needed — system tray notification is shown by FCM automatically
  // when the message has a `notification` payload and the app is in background.
}

// ── Bootstrap ─────────────────────────────────────────────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Register background handler BEFORE runApp
  FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

  // ── Android: create high-importance notification channel ──────────────────
  await localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_channel);

  // ── Android: initialize local notifications plugin ────────────────────────
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false, // we request below via FCM
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
  );
  await localNotifications.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (details) {
      // User tapped a local notification while app was in foreground
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const NotificationScreen()),
      );
    },
  );

  // ── Request permission (iOS + Android 13+) ────────────────────────────────
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // ── iOS: show notifications when app is in foreground ────────────────────
  await FirebaseMessaging.instance
      .setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(const SkillRentingApp());
}

// ── App ───────────────────────────────────────────────────────────────────────

class SkillRentingApp extends StatefulWidget {
  const SkillRentingApp({super.key});

  @override
  State<SkillRentingApp> createState() => _SkillRentingAppState();
}

class _SkillRentingAppState extends State<SkillRentingApp> {
  @override
  void initState() {
    super.initState();
    _setupFcmListeners();
  }

  void _setupFcmListeners() {
    // ── 1. Foreground messages ─────────────────────────────────────────────
    // FCM does NOT show a system notification when the app is in the foreground.
    // We use flutter_local_notifications to show it ourselves.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    });

    // ── 2. App in background — user taps the notification ─────────────────
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final type = message.data['type'] as String?;
      NotificationRouter.navigate(
        navigatorState: navigatorKey.currentState,
        type: type,
      );
    });

    // ── 3. App was fully terminated — user taps the notification ─────────
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        final type = message.data['type'] as String?;
        Future.delayed(const Duration(milliseconds: 500), () {
          NotificationRouter.navigate(
            navigatorState: navigatorKey.currentState,
            type: type,
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // <-- wire the global key here
      debugShowCheckedModeBanner: false,
      title: 'Skill Renting App',

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        scaffoldBackgroundColor: Colors.grey.shade50,

        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      home: const AppEntry(),

      routes: {
        '/login':    (_) => LoginScreen(),
        '/register': (_) => RegisterScreen(),
      },
    );
  }
}
