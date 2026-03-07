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

    startDate: {
      type: Date,
      required: true,
    },

    endDate: {
      type: Date,
    },

    duration: {
      type: String,
    },

    jobAddress: {
      houseName: { type: String },
      locality: { type: String },
      pincode: { type: String },
      district: { type: String },
    },

    // ── GPS Location ──────────────────────────────────────────────────────────
    jobGpsLocation: {
      lat: { type: Number },
      lng: { type: Number },
    },

    // pending  → seeker hasn't responded yet
    // provided → seeker shared GPS (or auto-filled from saved home)
    // skipped  → seeker chose to skip
    gpsLocationStatus: {
      type: String,
      enum: ["pending", "provided", "skipped"],
      default: "pending",
    },
    // ─────────────────────────────────────────────────────────────────────────

    jobDescription: {
      type: String,
    },

    distanceKmEstimate: {
      type: Number,
    },

    pricingSnapshot: {
      amount: {
        type: Number,
        required: true,
      },
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

    cancellationReason: {
      type: String,
    },

    isDisputed: {
      type: Boolean,
      default: false,
    },

    isReviewed: {
      type: Boolean,
      default: false,
    },

    rescheduleRequested: {
      type: Boolean,
      default: false,
    },

    rescheduleReason: {
      type: String,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model("Booking", bookingSchema);
