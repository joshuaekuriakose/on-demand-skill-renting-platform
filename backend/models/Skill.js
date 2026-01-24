const mongoose = require("mongoose");

const skillSchema = new mongoose.Schema(
  {
    provider: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },

    title: {
      type: String,
      required: true,
      trim: true,
    },

    description: {
      type: String,
      required: true,
    },

    category: {
      type: String,
      required: true,
      index: true,
    },

    skillLevel: {
      type: String,
      enum: ["beginner", "intermediate", "expert"],
      default: "beginner",
    },
    
    pricing: {
        amount: {
            type: Number,
            required: true,
        },
        
        unit: {
            type: String,
            enum: ["hour", "day", "week", "month", "task"],
            default: "hour",
        },
    },
    
    availability: {
      type: String,
    },

    location: {
      type: String,
      index: true,
    },

    tags: [
      {
        type: String,
      },
    ],

    rating: {
      type: Number,
      default: 0,
    },

    totalReviews: {
      type: Number,
      default: 0,
    },

    isActive: {
      type: Boolean,
      default: true,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model("Skill", skillSchema);
