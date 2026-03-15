import 'package:flutter/material.dart';
import 'package:skill_renting_app/features/bookings/screens/seeker_bookings_screen.dart';
import 'package:skill_renting_app/features/bookings/screens/provider_bookings_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Notification types sent by the backend
// ─────────────────────────────────────────────────────────────────────────────
//
//  Seeker receives:
//    booking_accepted  → My Bookings (seeker)
//    booking_rejected  → My Bookings (seeker)
//    booking_completed → My Bookings (seeker)
//    begin_otp         → My Bookings (seeker) — OTP shown inline
//    complete_otp      → My Bookings (seeker) — OTP shown inline
//    service_started   → My Bookings (seeker)
//
//  Provider receives:
//    new_request       → Job Queue (provider) — Requests tab
//    payment           → Job Queue (provider) — Bookings tab

class NotificationRouter {
  // Seeker-facing notification types
  static const _seekerTypes = {
    'booking_accepted',
    'booking_rejected',
    'booking_completed',
    'begin_otp',
    'complete_otp',
    'service_started',
  };

  // Provider-facing notification types
  static const _providerTypes = {
    'new_request',
    'payment',
  };

  /// Navigates to the correct screen for a given notification type.
  /// [navigatorState] — pass `navigatorKey.currentState`
  /// [type]           — the `type` field from the notification/FCM data
  static void navigate({
    required NavigatorState? navigatorState,
    required String? type,
  }) {
    if (navigatorState == null || type == null) {
      // Fallback — no type means we can't route, do nothing
      return;
    }

    if (_seekerTypes.contains(type)) {
      navigatorState.push(
        MaterialPageRoute(builder: (_) => const SeekerBookingsScreen()),
      );
    } else if (_providerTypes.contains(type)) {
      navigatorState.push(
        MaterialPageRoute(builder: (_) => const ProviderBookingsScreen()),
      );
    }
    // Unknown type — silently ignore (screen stays as-is)
  }
}
