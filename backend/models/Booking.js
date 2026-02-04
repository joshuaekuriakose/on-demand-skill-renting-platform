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
  default: false
}


  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model("Booking", bookingSchema);
