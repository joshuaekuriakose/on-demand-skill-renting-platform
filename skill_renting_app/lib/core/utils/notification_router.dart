import 'package:flutter/material.dart';
import 'package:skill_renting_app/features/bookings/screens/seeker_bookings_screen.dart';
import 'package:skill_renting_app/features/bookings/screens/provider_bookings_screen.dart';
import 'package:skill_renting_app/features/chat/chat_screen.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';

class NotificationRouter {
  static const _seekerTypes = {
    'booking_accepted',
    'booking_rejected',
    'booking_completed',
    'begin_otp',
    'complete_otp',
    'service_started',
  };

  static const _providerTypes = {
    'new_request',
    'payment',
  };

  /// Navigate from a notification tap.
  /// [data] — the full FCM message.data map (includes type + bookingId).
  static Future<void> navigate({
    required NavigatorState? navigatorState,
    required String? type,
    Map<String, dynamic>? data,
  }) async {
    if (navigatorState == null || type == null) return;

    if (type == 'new_message') {
      final bookingId = data?['bookingId']?.toString();
      if (bookingId == null || bookingId.isEmpty) return;

      // Determine who sent the message so we know the other person's name.
      // We don't have a name here, so open a generic chat screen labelled "Chat".
      final myId = await AuthStorage.getUserId();
      navigatorState.push(MaterialPageRoute(
        builder: (_) => ChatScreen(
          bookingId:       bookingId,
          otherPersonName: "Chat",
          currentUserId:   myId,
        ),
      ));
      return;
    }

    if (_seekerTypes.contains(type)) {
      navigatorState.push(
          MaterialPageRoute(builder: (_) => const SeekerBookingsScreen()));
    } else if (_providerTypes.contains(type)) {
      navigatorState.push(
          MaterialPageRoute(builder: (_) => const ProviderBookingsScreen()));
    }
  }
}
