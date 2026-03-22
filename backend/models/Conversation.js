const mongoose = require("mongoose");

// A direct conversation between one seeker and one provider.
// Created automatically when a seeker sends the first message to a provider
// from the Explore / skill-detail screen.
//
// Rules:
//  • Only seekers can create a new direct conversation.
//  • Providers can reply once the seeker has initiated.
//  • There is at most ONE conversation per (seeker, provider) pair.

const conversationSchema = new mongoose.Schema(
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

    // Optional — the skill the seeker was viewing when they sent the first message.
    // Used only for display context; does not restrict the conversation.
    skill: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Skill",
      default: null,
    },
  },
  { timestamps: true }
);

// Enforce one conversation per seeker-provider pair.
conversationSchema.index({ seeker: 1, provider: 1 }, { unique: true });

module.exports = mongoose.model("Conversation", conversationSchema);
