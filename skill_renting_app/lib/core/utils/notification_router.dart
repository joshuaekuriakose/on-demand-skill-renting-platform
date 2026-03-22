import 'package:flutter/material.dart';
import 'package:skill_renting_app/features/bookings/screens/seeker_bookings_screen.dart';
import 'package:skill_renting_app/features/bookings/screens/provider_bookings_screen.dart';
import 'package:skill_renting_app/features/chat/chat_screen.dart';
import 'package:skill_renting_app/features/reviews/screens/review_screen.dart';
import 'package:skill_renting_app/features/bookings/booking_service.dart';
import 'package:skill_renting_app/features/bookings/models/booking_model.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';

class NotificationRouter {
  static const _seekerTypes = {
    'booking_accepted',
    'booking_rejected',
    'booking_completed',
    'begin_otp',
    'complete_otp',
    'service_started',
    'no_response_warning',
    'auto_cancelled',
  };

  static const _providerTypes = {
    'new_request',
    'payment',
  };

  /// Navigate from a notification tap.
  /// [data] — the full FCM message.data map (includes type + bookingId/conversationId).
  static Future<void> navigate({
    required NavigatorState? navigatorState,
    required String? type,
    Map<String, dynamic>? data,
  }) async {
    if (navigatorState == null || type == null) return;

    // ── Booking chat notification ──────────────────────────────────────────
    if (type == 'new_message') {
      final bookingId = data?['bookingId']?.toString();
      if (bookingId == null || bookingId.isEmpty) return;
      final myId = await AuthStorage.getUserId();
      navigatorState.push(MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatType:        "booking",
          bookingId:       bookingId,
          otherPersonName: "Chat",
          currentUserId:   myId,
        ),
      ));
      return;
    }

    // ── Direct chat notification ───────────────────────────────────────────
    if (type == 'new_direct_message') {
      final conversationId = data?['conversationId']?.toString();
      if (conversationId == null || conversationId.isEmpty) return;
      final myId = await AuthStorage.getUserId();
      navigatorState.push(MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatType:        "direct",
          conversationId:  conversationId,
          otherPersonName: "Message",
          currentUserId:   myId,
        ),
      ));
      return;
    }

    // ── Auto-cancel review invite ──────────────────────────────────────────
    // Tapping this notification opens the ReviewScreen directly so the seeker
    // can rate the provider's non-responsiveness without navigating into bookings.
    if (type == 'auto_cancel_review_invite') {
      final bookingId = data?['bookingId']?.toString();
      if (bookingId == null || bookingId.isEmpty) {
        // Fallback: open seeker bookings list
        navigatorState.push(
            MaterialPageRoute(builder: (_) => const SeekerBookingsScreen()));
        return;
      }

      // Fetch the booking to build a BookingModel for ReviewScreen
      try {
        final bookings = await BookingService.fetchMyBookings();
        final booking = bookings.firstWhere(
          (b) => b.id == bookingId,
          orElse: () => throw Exception("not found"),
        );

        // Don't open if already reviewed
        if (booking.isReviewed) return;

        navigatorState.push(MaterialPageRoute(
          builder: (_) => ReviewScreen(
            booking:          booking,
            isForNoResponse:  true,
          ),
        ));
      } catch (e) {
        // If fetch fails, fall back to the bookings list.
        // Also show a user-visible message (no silent failure).
        try {
          final ctx = navigatorState.context;
          if (ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text("Couldn't open review (${e.toString()})"),
              ),
            );
          }
        } catch (_) {
          // Ignore UI fallback errors.
        }
        navigatorState.push(
          MaterialPageRoute(builder: (_) => const SeekerBookingsScreen()),
        );
      }
      return;
    }

    // ── Standard booking status types ─────────────────────────────────────
    if (_seekerTypes.contains(type)) {
      navigatorState.push(
          MaterialPageRoute(builder: (_) => const SeekerBookingsScreen()));
    } else if (_providerTypes.contains(type)) {
      navigatorState.push(
          MaterialPageRoute(builder: (_) => const ProviderBookingsScreen()));
    }
  }
}
