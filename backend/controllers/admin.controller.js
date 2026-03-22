const User       = require("../models/User");
const Skill      = require("../models/Skill");
const Booking    = require("../models/Booking");
const Review     = require("../models/Review");
const BlockedSlot = require("../models/BlockedSlot");

// ── GET /api/admin/stats ───────────────────────────────────────────────────────
exports.getStats = async (req, res) => {
  try {
    const [
      totalUsers,
      totalSkills,
      totalBookings,
      completedBookings,
      pendingBookings,
    ] = await Promise.all([
      User.countDocuments({ role: { $ne: "admin" } }),
      Skill.countDocuments({ isActive: true }),
      Booking.countDocuments(),
      Booking.countDocuments({ status: "completed" }),
      Booking.countDocuments({ status: "requested" }),
    ]);

    // Total revenue = sum of totalAmount on paid completed bookings
    const revenueAgg = await Booking.aggregate([
      { $match: { status: "completed", paymentStatus: "paid" } },
      { $group: { _id: null, total: { $sum: "$totalAmount" } } },
    ]);
    const totalRevenue = revenueAgg[0]?.total || 0;

    // Active providers = users who have at least one active skill
    const providerIds = await Skill.distinct("provider", { isActive: true });

    res.json({
      totalUsers,
      totalProviders: providerIds.length,
      totalSkills,
      totalBookings,
      completedBookings,
      pendingBookings,
      totalRevenue,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ── GET /api/admin/users ───────────────────────────────────────────────────────
// Query params: ?role=user|provider&search=name_or_email&page=1&limit=20
exports.getUsers = async (req, res) => {
  try {
    const { role, search, page = 1, limit = 30 } = req.query;

    const filter = { role: { $ne: "admin" } };
    if (search) {
      filter.$or = [
        { name:  { $regex: search, $options: "i" } },
        { email: { $regex: search, $options: "i" } },
        { phone: { $regex: search, $options: "i" } },
      ];
    }

    // "provider" = user who has at least one skill
    if (role === "provider") {
      const providerIds = await Skill.distinct("provider");
      filter._id = { $in: providerIds };
    } else if (role === "seeker") {
      const providerIds = await Skill.distinct("provider");
      filter._id = { $nin: providerIds };
    }

    const users = await User.find(filter)
      .select("-password")
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(Number(limit))
      .lean();

    const total = await User.countDocuments(filter);

    // Tag each user as provider or seeker
    const allProviderIds = (await Skill.distinct("provider")).map(String);
    const tagged = users.map((u) => ({
      ...u,
      isProvider: allProviderIds.includes(String(u._id)),
    }));

    res.json({ users: tagged, total, page: Number(page), limit: Number(limit) });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ── GET /api/admin/users/:id ───────────────────────────────────────────────────
exports.getUserDetail = async (req, res) => {
  try {
    const user = await User.findById(req.params.id)
      .select("-password")
      .lean();
    if (!user) return res.status(404).json({ message: "User not found" });

    // Skills offered (if provider)
    const skills = await Skill.find({ provider: user._id }).lean();

    // Bookings as seeker
    const seekerBookings = await Booking.find({ seeker: user._id })
      .populate("skill", "title pricing")
      .populate("provider", "name phone")
      .sort({ createdAt: -1 })
      .lean();

    // Bookings as provider
    const providerBookings = await Booking.find({ provider: user._id })
      .populate("skill", "title pricing")
      .populate("seeker", "name phone")
      .sort({ createdAt: -1 })
      .lean();

    // Reviews received (as provider)
    const reviewsReceived = await Review.find({ provider: user._id })
      .populate("reviewer", "name")
      .sort({ createdAt: -1 })
      .lean();

    res.json({
      user,
      skills,
      seekerBookings,
      providerBookings,
      reviewsReceived,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ── GET /api/admin/bookings ────────────────────────────────────────────────────
// Query: ?status=completed&search=seekerName&dateFrom=&dateTo=&page=1&limit=20
exports.getBookings = async (req, res) => {
  try {
    const { status, search, dateFrom, dateTo, page = 1, limit = 30 } = req.query;

    const filter = {};
    if (status) filter.status = status;
    if (dateFrom || dateTo) {
      filter.startDate = {};
      if (dateFrom) filter.startDate.$gte = new Date(dateFrom);
      if (dateTo) {
        const to = new Date(dateTo);
        to.setHours(23, 59, 59, 999);
        filter.startDate.$lte = to;
      }
    }

    let bookings = await Booking.find(filter)
      .populate("seeker",   "name phone address")
      .populate("provider", "name phone")
      .populate("skill",    "title pricing")
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(Number(limit))
      .lean();

    // Filter by seeker/provider name if search given
    if (search) {
      const s = search.toLowerCase();
      bookings = bookings.filter(
        (b) =>
          b.seeker?.name?.toLowerCase().includes(s) ||
          b.provider?.name?.toLowerCase().includes(s) ||
          b.skill?.title?.toLowerCase().includes(s)
      );
    }

    const total = await Booking.countDocuments(filter);

    res.json({ bookings, total, page: Number(page), limit: Number(limit) });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ── POST /api/admin/reports/user ───────────────────────────────────────────────
// Generate a report for a specific user (as seeker) over a date range.
// Body: { userId, dateFrom, dateTo }
exports.generateUserReport = async (req, res) => {
  try {
    const { userId, dateFrom, dateTo } = req.body;
    if (!userId || !dateFrom || !dateTo)
      return res.status(400).json({ message: "userId, dateFrom, dateTo required" });

    const user = await User.findById(userId).select("-password").lean();
    if (!user) return res.status(404).json({ message: "User not found" });

    const from = new Date(dateFrom);
    const to   = new Date(dateTo);
    to.setHours(23, 59, 59, 999);

    const bookings = await Booking.find({
      seeker:    user._id,
      startDate: { $gte: from, $lte: to },
    })
      .populate("skill",    "title pricing")
      .populate("provider", "name phone address")
      .sort({ startDate: 1 })
      .lean();

    if (bookings.length === 0)
      return res.json({ empty: true, message: "No bookings in selected range" });

    // Reviews given by this user
    const bookingIds = bookings.map((b) => b._id);
    const reviews = await Review.find({ booking: { $in: bookingIds } }).lean();
    const reviewMap = {};
    reviews.forEach((r) => { reviewMap[r.booking.toString()] = r; });

    const rows = bookings.map((b) => {
      const review = reviewMap[b._id.toString()] || null;
      return {
        bookingId:      b._id.toString(),
        skillTitle:     b.skill?.title || "N/A",
        pricingUnit:    b.skill?.pricing?.unit || "hour",
        fee:            b.pricingSnapshot?.amount || 0,
        providerName:   b.provider?.name || "N/A",
        providerPhone:  b.provider?.phone || "N/A",
        providerDistrict: b.provider?.address?.district || "N/A",
        description:    b.jobDescription || "",
        startDate:      b.startDate,
        endDate:        b.endDate,
        status:         b.status,
        extraCharges:   b.extraCharges || 0,
        totalAmount:    b.totalAmount || b.pricingSnapshot?.amount || 0,
        paymentStatus:  b.paymentStatus || "pending",
        review: review ? { rating: review.rating, comment: review.comment || "" } : null,
      };
    });

    const totalSpent = rows
      .filter((r) => r.paymentStatus === "paid")
      .reduce((s, r) => s + r.totalAmount, 0);

    res.json({
      reportData: {
        type:         "user",
        userName:     user.name,
        userPhone:    user.phone,
        userEmail:    user.email,
        userAddress:  user.address,
        dateFrom:     from,
        dateTo:       to,
        bookings:     rows,
        totalSpent,
      },
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ── POST /api/admin/reports/provider ──────────────────────────────────────────
// Generate a full provider report over a date range (all skills).
// Body: { providerId, dateFrom, dateTo }
exports.generateProviderReport = async (req, res) => {
  try {
    const { providerId, dateFrom, dateTo } = req.body;
    if (!providerId || !dateFrom || !dateTo)
      return res.status(400).json({ message: "providerId, dateFrom, dateTo required" });

    const provider = await User.findById(providerId).select("-password").lean();
    if (!provider) return res.status(404).json({ message: "Provider not found" });

    const from = new Date(dateFrom);
    const to   = new Date(dateTo);
    to.setHours(23, 59, 59, 999);

    const skills = await Skill.find({ provider: provider._id }).lean();
    if (skills.length === 0)
      return res.json({ empty: true, message: "This user has no services" });

    const skillSections = [];

    for (const skill of skills) {
      const bookings = await Booking.find({
        provider:  provider._id,
        skill:     skill._id,
        startDate: { $gte: from, $lte: to },
      })
        .populate("seeker", "name phone address")
        .lean();

      const bookingIds = bookings.map((b) => b._id);
      const reviews = await Review.find({ booking: { $in: bookingIds } }).lean();
      const reviewMap = {};
      reviews.forEach((r) => { reviewMap[r.booking.toString()] = r; });

      const blocked = await BlockedSlot.find({
        provider:  provider._id,
        skill:     skill._id,
        startDate: { $gte: from },
        endDate:   { $lte: to },
      }).lean();

      const rows = bookings.map((b) => {
        const review = reviewMap[b._id.toString()] || null;
        return {
          bookingId:    b._id.toString(),
          seekerName:   b.seeker?.name  || "N/A",
          seekerPhone:  b.seeker?.phone || "N/A",
          locality:     b.jobAddress?.locality || b.seeker?.address?.locality || "N/A",
          district:     b.jobAddress?.district || b.seeker?.address?.district || "N/A",
          description:  b.jobDescription || "",
          startDate:    b.startDate,
          endDate:      b.endDate,
          status:       b.status,
          fee:          b.pricingSnapshot?.amount || 0,
          feeUnit:      b.pricingSnapshot?.unit   || "hour",
          extraCharges: b.extraCharges  || 0,
          totalAmount:  b.totalAmount   || b.pricingSnapshot?.amount || 0,
          paymentStatus:b.paymentStatus || "pending",
          review: review ? { rating: review.rating, comment: review.comment || "" } : null,
        };
      });

      const totalReceived = rows
        .filter((r) => r.paymentStatus === "paid")
        .reduce((s, r) => s + r.totalAmount, 0);

      skillSections.push({
        skillTitle:   skill.title,
        skillLevel:   skill.skillLevel,
        pricingUnit:  skill.pricing?.unit   || "hour",
        pricePerUnit: skill.pricing?.amount || 0,
        bookings:     rows,
        blockedSlots: blocked.map((bl) => ({
          startDate: bl.startDate,
          endDate:   bl.endDate,
          reason:    bl.reason || "Off",
        })),
        totalReceived,
      });
    }

    const grandTotal = skillSections.reduce((s, sec) => s + sec.totalReceived, 0);

    res.json({
      reportData: {
        type:          "provider",
        providerName:  provider.name,
        providerPhone: provider.phone,
        providerEmail: provider.email,
        dateFrom:      from,
        dateTo:        to,
        skillSections,
        grandTotal,
      },
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ── GET /api/admin/revenue ─────────────────────────────────────────────────────
// Completed + paid bookings with full details
exports.getRevenue = async (req, res) => {
  try {
    const { dateFrom, dateTo, page = 1, limit = 30 } = req.query;
    const filter = { status: "completed", paymentStatus: "paid" };
    if (dateFrom || dateTo) {
      filter.startDate = {};
      if (dateFrom) filter.startDate.$gte = new Date(dateFrom);
      if (dateTo) { const to = new Date(dateTo); to.setHours(23,59,59,999); filter.startDate.$lte = to; }
    }
    const bookings = await Booking.find(filter)
      .populate("seeker",   "name phone address")
      .populate("provider", "name phone")
      .populate("skill",    "title pricing")
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(Number(limit))
      .lean();
    const total = await Booking.countDocuments(filter);
    const revenueAgg = await Booking.aggregate([
      { $match: filter },
      { $group: { _id: null, total: { $sum: "$totalAmount" } } },
    ]);
    res.json({ bookings, total, grandTotal: revenueAgg[0]?.total || 0, page: Number(page) });
  } catch (err) { res.status(500).json({ message: err.message }); }
};

// ── GET /api/admin/bookings/skills ─────────────────────────────────────────────
// Returns list of skills that have bookings, grouped with counts
exports.getBookingsBySkill = async (req, res) => {
  try {
    const { search, dateFrom, dateTo } = req.query;
    const matchStage = {};
    if (dateFrom || dateTo) {
      matchStage.startDate = {};
      if (dateFrom) matchStage.startDate.$gte = new Date(dateFrom);
      if (dateTo) { const to = new Date(dateTo); to.setHours(23,59,59,999); matchStage.startDate.$lte = to; }
    }
    const grouped = await Booking.aggregate([
      { $match: matchStage },
      { $group: {
          _id: "$skill",
          totalBookings: { $sum: 1 },
          completed: { $sum: { $cond: [{ $eq: ["$status","completed"] }, 1, 0] } },
          pending:   { $sum: { $cond: [{ $eq: ["$status","requested"] }, 1, 0] } },
          revenue:   { $sum: { $cond: [{ $eq: ["$paymentStatus","paid"] }, "$totalAmount", 0] } },
          lastBooking: { $max: "$startDate" },
      }},
      { $sort: { totalBookings: -1 } },
    ]);
    const skillIds = grouped.map(g => g._id);
    const skills = await Skill.find({ _id: { $in: skillIds } })
      .populate("provider", "name")
      .lean();
    const skillMap = {};
    skills.forEach(s => { skillMap[String(s._id)] = s; });

    let result = grouped
      .map(g => ({ ...g, skill: skillMap[String(g._id)] || null }))
      .filter(g => g.skill != null);

    if (search) {
      const s = search.toLowerCase();
      result = result.filter(g =>
        g.skill?.title?.toLowerCase().includes(s) ||
        g.skill?.provider?.name?.toLowerCase().includes(s)
      );
    }
    res.json(result);
  } catch (err) { res.status(500).json({ message: err.message }); }
};

// ── GET /api/admin/bookings/skill/:skillId ─────────────────────────────────────
// All bookings for a specific skill
exports.getBookingsForSkill = async (req, res) => {
  try {
    const { status, dateFrom, dateTo } = req.query;
    const filter = { skill: req.params.skillId };
    if (status) filter.status = status;
    if (dateFrom || dateTo) {
      filter.startDate = {};
      if (dateFrom) filter.startDate.$gte = new Date(dateFrom);
      if (dateTo) { const to = new Date(dateTo); to.setHours(23,59,59,999); filter.startDate.$lte = to; }
    }
    const bookings = await Booking.find(filter)
      .populate("seeker",   "name phone address")
      .populate("provider", "name phone")
      .populate("skill",    "title pricing")
      .sort({ startDate: -1 })
      .lean();

    const bookingIds = bookings.map(b => b._id);
    const reviews = await Review.find({ booking: { $in: bookingIds } }).lean();
    const reviewMap = {};
    reviews.forEach(r => { reviewMap[r.booking.toString()] = r; });
    const withReviews = bookings.map(b => ({ ...b, review: reviewMap[b._id.toString()] || null }));
    res.json(withReviews);
  } catch (err) { res.status(500).json({ message: err.message }); }
};

// ── GET /api/admin/districts ───────────────────────────────────────────────────
exports.getDistricts = async (req, res) => {
  try {
    const districts = await User.distinct("address.district", {
      "address.district": { $ne: null, $ne: "" }
    });
    res.json(districts.filter(Boolean).sort());
  } catch (err) { res.status(500).json({ message: err.message }); }
};

// ── POST /api/admin/reports/bulk-users ────────────────────────────────────────
// Bulk report: filter by role + district + pricingUnit
exports.generateBulkUserReport = async (req, res) => {
  try {
    const { role, district, pricingUnit, dateFrom, dateTo } = req.body;
    if (!dateFrom || !dateTo)
      return res.status(400).json({ message: "dateFrom and dateTo required" });

    const from = new Date(dateFrom);
    const to   = new Date(dateTo); to.setHours(23,59,59,999);

    // Build user filter
    const userFilter = { role: { $ne: "admin" } };
    if (district) userFilter["address.district"] = { $regex: district, $options: "i" };

    // Role filter: provider = has skills, seeker = no skills
    let providerIds = (await Skill.distinct("provider")).map(String);
    if (pricingUnit) {
      // narrow providers to those with matching pricing unit
      const skillIds = await Skill.distinct("provider", { "pricing.unit": pricingUnit });
      providerIds = skillIds.map(String);
    }
    if (role === "provider") {
      userFilter._id = { $in: providerIds };
    } else if (role === "seeker") {
      userFilter._id = { $nin: providerIds };
    }

    const users = await User.find(userFilter).select("-password").lean();
    if (users.length === 0)
      return res.json({ empty: true, message: "No users match the selected filters" });

    const reportRows = [];
    for (const user of users) {
      const isProvider = providerIds.includes(String(user._id));
      const bookings = await Booking.find({
        [isProvider ? "provider" : "seeker"]: user._id,
        startDate: { $gte: from, $lte: to },
      })
        .populate("skill", "title pricing")
        .lean();

      reportRows.push({
        userId:    user._id,
        name:      user.name,
        phone:     user.phone,
        email:     user.email,
        district:  user.address?.district || "-",
        locality:  user.address?.locality || "-",
        isProvider,
        bookingCount: bookings.length,
        totalEarned: isProvider
          ? bookings.filter(b => b.paymentStatus === "paid").reduce((s,b) => s + (b.totalAmount || 0), 0)
          : 0,
        totalSpent: !isProvider
          ? bookings.filter(b => b.paymentStatus === "paid").reduce((s,b) => s + (b.totalAmount || 0), 0)
          : 0,
        bookings: bookings.map(b => ({
          skillTitle:   b.skill?.title   || "-",
          pricingUnit:  b.skill?.pricing?.unit || "-",
          status:       b.status,
          startDate:    b.startDate,
          totalAmount:  b.totalAmount || b.pricingSnapshot?.amount || 0,
          paymentStatus:b.paymentStatus,
        })),
      });
    }

    res.json({
      reportData: {
        type: "bulk_users",
        filters: { role: role || "all", district: district || "all", pricingUnit: pricingUnit || "all" },
        dateFrom: from, dateTo: to,
        users: reportRows,
        grandTotal: reportRows.reduce((s,u) => s + (u.totalEarned || u.totalSpent || 0), 0),
      }
    });
  } catch (err) { res.status(500).json({ message: err.message }); }
};

// ── POST /api/admin/reports/bookings ──────────────────────────────────────────
// Bookings report for a date range (all or by skill)
exports.generateBookingsReport = async (req, res) => {
  try {
    const { skillId, dateFrom, dateTo, status } = req.body;
    if (!dateFrom || !dateTo)
      return res.status(400).json({ message: "dateFrom and dateTo required" });
    const from = new Date(dateFrom);
    const to   = new Date(dateTo); to.setHours(23,59,59,999);

    const filter = { startDate: { $gte: from, $lte: to } };
    if (skillId) filter.skill = skillId;
    if (status)  filter.status = status;

    const bookings = await Booking.find(filter)
      .populate("seeker",   "name phone address")
      .populate("provider", "name phone")
      .populate("skill",    "title pricing skillLevel")
      .sort({ startDate: 1 })
      .lean();

    if (bookings.length === 0)
      return res.json({ empty: true, message: "No bookings found in selected range" });

    const bookingIds = bookings.map(b => b._id);
    const reviews = await Review.find({ booking: { $in: bookingIds } }).lean();
    const reviewMap = {};
    reviews.forEach(r => { reviewMap[r.booking.toString()] = r; });

    const rows = bookings.map(b => {
      const rev = reviewMap[b._id.toString()] || null;
      return {
        bookingId:    b._id.toString(),
        skillTitle:   b.skill?.title || "-",
        pricingUnit:  b.skill?.pricing?.unit || "hour",
        seekerName:   b.seeker?.name   || "-",
        seekerPhone:  b.seeker?.phone  || "-",
        locality:     b.jobAddress?.locality || b.seeker?.address?.locality || "-",
        district:     b.jobAddress?.district || b.seeker?.address?.district || "-",
        providerName: b.provider?.name  || "-",
        providerPhone:b.provider?.phone || "-",
        description:  b.jobDescription || "",
        startDate:    b.startDate,
        endDate:      b.endDate,
        status:       b.status,
        fee:          b.pricingSnapshot?.amount || 0,
        extraCharges: b.extraCharges  || 0,
        totalAmount:  b.totalAmount   || b.pricingSnapshot?.amount || 0,
        paymentStatus:b.paymentStatus || "pending",
        review: rev ? { rating: rev.rating, comment: rev.comment || "" } : null,
      };
    });

    const totalReceived = rows
      .filter(r => r.paymentStatus === "paid")
      .reduce((s,r) => s + r.totalAmount, 0);

    res.json({
      reportData: {
        type:          "bookings",
        skillTitle:    skillId ? (bookings[0]?.skill?.title || "-") : "All Skills",
        dateFrom:      from,
        dateTo:        to,
        bookings:      rows,
        totalReceived,
      }
    });
  } catch (err) { res.status(500).json({ message: err.message }); }
};
