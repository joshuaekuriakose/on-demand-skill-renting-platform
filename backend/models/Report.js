const mongoose = require("mongoose");

const reportSchema = new mongoose.Schema(
  {
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

    // auto_daily  → generated nightly for hourly providers
    // auto_weekly → generated every Sunday for daily providers
    // auto_monthly→ generated on 1st of month for all providers
    // custom      → provider requested with specific date range
    type: {
      type: String,
      enum: ["auto_daily", "auto_weekly", "auto_monthly", "custom"],
      required: true,
    },

    dateFrom: { type: Date, required: true },
    dateTo:   { type: Date, required: true },

    // Summary
    bookingCount: { type: Number, default: 0 },
    totalAmount:  { type: Number, default: 0 },

    // Full JSON blob so Flutter can rebuild PDF without a second query
    reportData: { type: mongoose.Schema.Types.Mixed, default: null },

    generatedAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Report", reportSchema);
