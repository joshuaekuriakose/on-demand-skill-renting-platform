const mongoose = require("mongoose");

const notificationSchema = mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    title: {
      type: String,
      required: true,
    },

    message: {
      type: String,
      required: true,
    },

    isRead: {
      type: Boolean,
      default: false,
    },

    // ── Used for in-app deep linking and action routing ───────────────────────
    // Values: "gps_required" | "gps_provided" | "booking_accepted" |
    //         "booking_rejected" | "booking_completed" | "new_booking" | "general"
    type: {
      type: String,
      default: "general",
    },

    // The booking this notification relates to (if any)
    bookingId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Booking",
      default: null,
    },
    // ─────────────────────────────────────────────────────────────────────────
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model("Notification", notificationSchema);
