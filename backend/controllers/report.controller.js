const Report    = require("../models/Report");
const Booking   = require("../models/Booking");
const Review    = require("../models/Review");
const Skill     = require("../models/Skill");
const User      = require("../models/User");
const BlockedSlot = require("../models/BlockedSlot");

// ── Helper: build full report data for one skill in a date range ──────────────
async function buildReportData({ provider, skill, dateFrom, dateTo }) {
  const from = new Date(dateFrom);
  const to   = new Date(dateTo);
  to.setHours(23, 59, 59, 999);

  // Bookings for this skill in range (completed + cancelled + rejected)
  const bookings = await Booking.find({
    provider:  provider._id,
    skill:     skill._id,
    startDate: { $gte: from, $lte: to },
    status:    { $in: ["completed", "cancelled", "rejected", "accepted", "in_progress"] },
  })
    .populate("seeker", "name phone address")
    .lean();

  // Reviews for these bookings
  const bookingIds = bookings.map((b) => b._id);
  const reviews = await Review.find({ booking: { $in: bookingIds } })
    .lean();
  const reviewMap = {};
  reviews.forEach((r) => { reviewMap[r.booking.toString()] = r; });

  // Blocked slots in range
  const blocked = await BlockedSlot.find({
    provider: provider._id,
    skill:    skill._id,
    startDate: { $gte: from },
    endDate:   { $lte: to },
  }).lean();

  // Build booking rows
  const rows = bookings.map((b) => {
    const review = reviewMap[b._id.toString()] || null;
    return {
      bookingId:    b._id.toString(),
      seekerName:   b.seeker?.name || "N/A",
      seekerPhone:  b.seeker?.phone || "N/A",
      locality:     b.jobAddress?.locality || b.seeker?.address?.locality || "N/A",
      district:     b.jobAddress?.district || b.seeker?.address?.district || "N/A",
      description:  b.jobDescription || "",
      startDate:    b.startDate,
      endDate:      b.endDate,
      status:       b.status,
      fee:          b.pricingSnapshot?.amount || 0,
      feeUnit:      b.pricingSnapshot?.unit || "—",
      extraCharges: b.extraCharges || 0,
      totalAmount:  b.totalAmount || b.pricingSnapshot?.amount || 0,
      paymentStatus:b.paymentStatus || "pending",
      review: review
        ? { rating: review.rating, comment: review.comment || "" }
        : null,
    };
  });

  const totalReceived = rows
    .filter((r) => r.paymentStatus === "paid")
    .reduce((s, r) => s + r.totalAmount, 0);

  const blockedRows = blocked.map((bl) => ({
    startDate: bl.startDate,
    endDate:   bl.endDate,
    reason:    bl.reason || "Off",
  }));

  return {
    providerName:  provider.name,
    providerPhone: provider.phone,
    skillTitle:    skill.title,
    skillLevel:    skill.skillLevel,
    pricingUnit:   skill.pricing?.unit || "hour",
    pricePerUnit:  skill.pricing?.amount || 0,
    dateFrom:      from,
    dateTo:        to,
    bookings:      rows,
    blockedSlots:  blockedRows,
    totalReceived,
  };
}

// ── POST /api/reports/generate ─────────────────────────────────────────────────
// Provider requests a custom report for a date range.
// Body: { skillId, dateFrom, dateTo }
exports.generateCustomReport = async (req, res) => {
  try {
    const { skillId, dateFrom, dateTo } = req.body;
    if (!skillId || !dateFrom || !dateTo)
      return res.status(400).json({ message: "skillId, dateFrom, dateTo required" });

    const skill = await Skill.findById(skillId);
    if (!skill) return res.status(404).json({ message: "Skill not found" });
    if (skill.provider.toString() !== req.user._id.toString())
      return res.status(403).json({ message: "Not authorized" });

    const provider = await User.findById(req.user._id).select("-password");
    const from = new Date(dateFrom);
    const to   = new Date(dateTo);
    to.setHours(23, 59, 59, 999);

    // Check activity in range
    const count = await Booking.countDocuments({
      provider: provider._id,
      skill:    skill._id,
      startDate: { $gte: from, $lte: to },
    });

    if (count === 0) {
      return res.status(200).json({ empty: true, message: "No activity in selected date range" });
    }

    const reportData = await buildReportData({ provider, skill, dateFrom: from, dateTo: to });

    const report = await Report.create({
      provider:     provider._id,
      skill:        skill._id,
      type:         "custom",
      dateFrom:     from,
      dateTo:       to,
      bookingCount: reportData.bookings.length,
      totalAmount:  reportData.totalReceived,
      reportData,
      generatedAt:  new Date(),
    });

    res.status(201).json(report);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ── GET /api/reports ───────────────────────────────────────────────────────────
// List all reports for the logged-in provider (newest first).
exports.getMyReports = async (req, res) => {
  try {
    const reports = await Report.find({ provider: req.user._id })
      .populate("skill", "title pricing")
      .sort({ generatedAt: -1 })
      .select("-reportData") // omit heavy blob in list view
      .lean();

    res.json(reports);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ── GET /api/reports/:id ───────────────────────────────────────────────────────
// Fetch full report data (including reportData blob) for PDF generation.
exports.getReportById = async (req, res) => {
  try {
    const report = await Report.findById(req.params.id)
      .populate("skill", "title pricing skillLevel")
      .lean();

    if (!report) return res.status(404).json({ message: "Report not found" });
    if (report.provider.toString() !== req.user._id.toString())
      return res.status(403).json({ message: "Not authorized" });

    res.json(report);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ── Internal: auto-generate report (called by scheduler) ─────────────────────
exports.autoGenerate = async ({ type, dateFrom, dateTo, pricingUnit }) => {
  try {
    // Find all skills matching the pricing unit
    const skills = await Skill.find({
      isActive: true,
      ...(pricingUnit ? { "pricing.unit": pricingUnit } : {}),
    }).lean();

    let created = 0;

    for (const skill of skills) {
      const provider = await User.findById(skill.provider).select("-password");
      if (!provider) continue;

      const count = await Booking.countDocuments({
        provider: provider._id,
        skill:    skill._id,
        startDate: { $gte: new Date(dateFrom), $lte: new Date(dateTo) },
      });

      if (count === 0) continue; // nothing to report

      const reportData = await buildReportData({
        provider, skill, dateFrom, dateTo,
      });

      await Report.create({
        provider:     provider._id,
        skill:        skill._id,
        type,
        dateFrom:     new Date(dateFrom),
        dateTo:       new Date(dateTo),
        bookingCount: reportData.bookings.length,
        totalAmount:  reportData.totalReceived,
        reportData,
        generatedAt:  new Date(),
      });

      created++;
    }

    console.log(`[Scheduler] ${type} reports generated: ${created}`);
  } catch (err) {
    console.error(`[Scheduler] Error generating ${type} reports:`, err.message);
  }
};
