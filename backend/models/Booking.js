const mongoose = require("mongoose");

const bookingSchema = new mongoose.Schema(
  {
    seeker: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    provider: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    skill: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Skill",
      required: true,
    },

    startDate: { type: Date, required: true },
    endDate:   { type: Date },
    duration:  { type: String },

    jobAddress: {
      houseName: { type: String },
      locality:  { type: String },
      pincode:   { type: String },
      district:  { type: String },
    },

    jobDescription: { type: String },

    distanceKmEstimate: { type: Number },

    jobGpsLocation: {
      lat: { type: Number },
      lng: { type: Number },
    },

    gpsLocationStatus: {
      type: String,
      enum: ["pending", "provided", "skipped"],
      default: "pending",
    },

    pricingSnapshot: {
      amount: { type: Number, required: true },
      unit: {
        type: String,
        enum: ["hour", "day", "week", "month", "task"],
        required: true,
      },
    },

    status: {
      type: String,
      enum: [
        "requested",
        "accepted",
        "rejected",
        "in_progress",
        "completed",
        "cancelled",
      ],
      default: "requested",
    },

    // ── OTP handshake ──────────────────────────────────────────────────────────
    // Provider clicks "Begin" → beginOtp generated, sent to seeker
    // Provider enters OTP seeker says → verified → in_progress, cleared
    beginOtp: { type: String, default: null },

    // Provider clicks "Complete" → completeOtp generated, sent to seeker
    // Provider enters OTP seeker says → verified → completed, cleared
    completeOtp: { type: String, default: null },

    // ── Timing & payment ───────────────────────────────────────────────────────
    actualEndTime: { type: Date, default: null },

    // Optional extra charges provider may add for time overrun
    extraCharges: { type: Number, default: 0 },

    // Base + extra; set when completeOtp is verified
    totalAmount: { type: Number, default: null },

    paymentStatus: {
      type: String,
      enum: ["pending", "paid"],
      default: "pending",
    },

    // ── Misc ───────────────────────────────────────────────────────────────────
    cancellationReason: { type: String },
    isDisputed:         { type: Boolean, default: false },
    isReviewed:         { type: Boolean, default: false },
    rescheduleRequested:{ type: Boolean, default: false },
    rescheduleReason:   { type: String },

    // ── Cancellation request flow (for in_progress bookings) ──────────────────
    // Seeker can request cancellation; provider must approve or deny.
    cancellationRequested:    { type: Boolean, default: false },
    cancellationRequestedAt:  { type: Date,    default: null },

    // ── No-response auto-cancel flow ─────────────────────────────────────────────────────
    // Set to the timestamp when the 10-min warning push was sent (prevents duplicate sends)
    warningNotifiedAt:          { type: Date,    default: null },
    // true when the scheduler auto-cancelled this booking due to no provider response
    autoCancelledForNoResponse: { type: Boolean, default: false },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Booking", bookingSchema);
