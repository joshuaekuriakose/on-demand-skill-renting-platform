const mongoose = require("mongoose");

const messageSchema = new mongoose.Schema(
  {
    // For booking-based chats (accepted / in_progress / completed bookings).
    booking: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Booking",
      default: null,
      index: true,
    },

    // For seeker-initiated direct conversations (Explore → Message provider).
    // Exactly one of `booking` or `conversation` is set on every message.
    conversation: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Conversation",
      default: null,
      index: true,
    },

    sender: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    // "seeker" | "provider"
    senderRole: {
      type: String,
      enum: ["seeker", "provider"],
      required: true,
    },

    text: {
      type: String,
      required: true,
      trim: true,
      maxlength: 1000,
    },

    isRead: {
      type: Boolean,
      default: false,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Message", messageSchema);
