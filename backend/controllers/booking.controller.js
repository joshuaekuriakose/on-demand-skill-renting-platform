const Booking = require("../models/Booking");
const Skill = require("../models/Skill");
const Notification = require("../models/Notification");
const sendPush = require("../utils/sendPush");
const User = require("../models/User");
const BlockedSlot = require("../models/BlockedSlot");
const {
  validateAndEnrichAddress,
  estimateDistanceKmByPins,
} = require("../utils/pincode");

exports.createBooking = async (req, res) => {
  try {
    const {
      skillId,
      startDate,
      endDate,
      duration,
      jobAddress,
      jobDescription,
    } = req.body;

    const skill = await Skill.findById(skillId);
    if (!skill) {
      return res.status(404).json({ message: "Skill not found" });
    }

    const unit = skill?.pricing?.unit;
    if (!unit) {
      return res.status(400).json({ message: "Skill pricing unit is missing" });
    }

    if (skill.provider.toString() === req.user._id.toString()) {
      return res
        .status(400)
        .json({ message: "You cannot book your own skill" });
    }

    if (!startDate || !endDate) {
      return res.status(400).json({
        message: "Start and end date are required",
      });
    }

    if (!jobDescription || !jobDescription.trim()) {
      return res.status(400).json({
        message: "Description is required",
      });
    }

    const newStart = new Date(startDate);
    const newEnd = new Date(endDate);

    if (isNaN(newStart.getTime()) || isNaN(newEnd.getTime())) {
      return res.status(400).json({ message: "Invalid date format" });
    }

    let normalizedStart = newStart;
    let normalizedEnd = newEnd;

    if (unit === "day" || unit === "daily") {
      normalizedStart = new Date(newStart);
      normalizedStart.setHours(0, 0, 0, 0);

      normalizedEnd = new Date(newEnd);
      normalizedEnd.setHours(0, 0, 0, 0);
    }

    if (normalizedStart.getTime() >= normalizedEnd.getTime()) {
      return res.status(400).json({
        message: "End date must be after start date",
      });
    }

    const overlappingBooking = await Booking.findOne({
      skill: skill._id,
      status: { $in: ["accepted", "in_progress"] },
      startDate: { $lt: normalizedEnd },
      endDate: { $gt: normalizedStart },
    });

    if (overlappingBooking) {
      return res.status(400).json({
        message: "This date is already booked",
      });
    }

    const providerUser = await User.findById(skill.provider);

    const existingPending = await Booking.findOne({
      seeker: req.user._id,
      skill: skill._id,
      status: "requested",
      startDate: { $lt: normalizedEnd },
      endDate: { $gt: normalizedStart },
    });

    if (existingPending) {
      return res.status(400).json({
        message: "Already request pending",
      });
    }

    let enrichedJobAddress;
    if (jobAddress) {
      const validated = await validateAndEnrichAddress(jobAddress);
      if (!validated.ok) {
        return res.status(400).json({ message: validated.message });
      }
      enrichedJobAddress = validated.address;
    }

    let distanceKmEstimate;
    const jobPin = enrichedJobAddress?.pincode;
    const providerPin = providerUser?.address?.pincode;

    if (jobPin && providerPin) {
      distanceKmEstimate = await estimateDistanceKmByPins(providerPin, jobPin);
    }

    const booking = await Booking.create({
      seeker: req.user._id,
      provider: skill.provider,
      skill: skill._id,
      startDate: normalizedStart,
      endDate: normalizedEnd,
      duration,
      jobAddress: enrichedJobAddress,
      jobDescription,
      distanceKmEstimate,
      pricingSnapshot: {
        amount: skill.pricing.amount,
        unit: skill.pricing.unit,
      },
    });

    await Notification.create({
      user: skill.provider,
      title: "New Booking Request",
      message: "Someone requested your skill: " + skill.title,
      type: "new_booking",
      bookingId: booking._id,
    });

    const provider = await User.findById(skill.provider);

    if (provider && provider.fcmToken) {
      await sendPush(
        provider.fcmToken,
        "New Booking",
        "Someone booked your skill",
        { bookingId: booking._id.toString(), type: "new_booking" }
      );
    }

    res.status(201).json(booking);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.getOccupiedSlots = async (req, res) => {
  try {
    const { skillId } = req.params;
    const { date } = req.query;

    if (!date) {
      return res.status(400).json({
        message: "Date query parameter is required",
      });
    }

    const startOfDay = new Date(date);
    const endOfDay = new Date(date);

    if (isNaN(startOfDay) || isNaN(endOfDay)) {
      return res.status(400).json({
        message: "Invalid date format",
      });
    }

    startOfDay.setHours(0, 0, 0, 0);
    endOfDay.setHours(23, 59, 59, 999);

    const bookings = await Booking.find({
      skill: skillId,
      status: { $in: ["accepted", "in_progress"] },
      startDate: { $lt: endOfDay },
      endDate: { $gt: startOfDay },
    }).select("startDate endDate");

    const blocks = await BlockedSlot.find({
      skill: skillId,
      startDate: { $lt: endOfDay },
      endDate: { $gt: startOfDay },
    }).select("startDate endDate");

    const combined = [
      ...bookings.map((b) => ({
        startDate: b.startDate,
        endDate: b.endDate,
        type: "booking",
      })),
      ...blocks.map((b) => ({
        startDate: b.startDate,
        endDate: b.endDate,
        type: "blocked",
      })),
    ];

    res.json(combined);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.getMyBookings = async (req, res) => {
  try {
    const bookings = await Booking.find({ seeker: req.user._id })
      .populate("skill")
      .populate("provider", "name email");

    res.status(200).json(bookings);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.getProviderBookings = async (req, res) => {
  try {
    const bookings = await Booking.find({ provider: req.user._id })
      .populate("skill")
      .populate("seeker", "name email");

    res.status(200).json(bookings);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.acceptBooking = async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);

    if (!booking) {
      return res.status(404).json({ message: "Booking not found" });
    }

    if (booking.provider.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: "Not authorized" });
    }

    if (booking.status !== "requested") {
      return res.status(400).json({ message: "Booking cannot be accepted" });
    }

    booking.status = "accepted";

    // ── GPS auto-fill: check if seeker has a saved home GPS location ──────────
    const seeker = await User.findById(booking.seeker);

    if (
      seeker &&
      seeker.homeGpsLocation &&
      seeker.homeGpsLocation.lat != null &&
      seeker.homeGpsLocation.lng != null
    ) {
      // Auto-fill job GPS from seeker's saved home location
      booking.jobGpsLocation = {
        lat: seeker.homeGpsLocation.lat,
        lng: seeker.homeGpsLocation.lng,
      };
      booking.gpsLocationStatus = "provided";
    } else {
      // Mark as pending — seeker must provide GPS manually
      booking.gpsLocationStatus = "pending";
    }
    // ─────────────────────────────────────────────────────────────────────────

    await booking.save();

    // Auto-reject conflicting bookings
    const toAutoReject = await Booking.find({
      _id: { $ne: booking._id },
      skill: booking.skill,
      status: "requested",
      startDate: { $lt: booking.endDate },
      endDate: { $gt: booking.startDate },
    }).select("_id seeker");

    if (toAutoReject.length > 0) {
      await Booking.updateMany(
        { _id: { $in: toAutoReject.map((b) => b._id) } },
        { $set: { status: "rejected" } }
      );

      await Promise.all(
        toAutoReject.map(async (b) => {
          await Notification.create({
            user: b.seeker,
            title: "Booking Rejected",
            message:
              "Your booking request was rejected because another request was accepted for the same slot.",
            type: "booking_rejected",
            bookingId: b._id,
          });

          const rejectedSeeker = await User.findById(b.seeker);
          if (rejectedSeeker && rejectedSeeker.fcmToken) {
            await sendPush(
              rejectedSeeker.fcmToken,
              "Booking Rejected",
              "Another request was accepted for the same slot",
              { bookingId: b._id.toString(), type: "booking_rejected" }
            );
          }
        })
      );
    }

    // ── Notify seeker: accepted + GPS request (if needed) ────────────────────
    if (booking.gpsLocationStatus === "provided") {
      // GPS was auto-filled; just notify acceptance
      await Notification.create({
        user: booking.seeker,
        title: "Booking Accepted",
        message: "Your booking was accepted. Your saved home location has been shared with the provider.",
        type: "booking_accepted",
        bookingId: booking._id,
      });

      if (seeker && seeker.fcmToken) {
        await sendPush(
          seeker.fcmToken,
          "Booking Accepted",
          "Your saved home location was shared with the provider.",
          { bookingId: booking._id.toString(), type: "booking_accepted" }
        );
      }

      // Notify provider that GPS is ready
      const provider = await User.findById(booking.provider);
      await Notification.create({
        user: booking.provider,
        title: "GPS Location Ready",
        message: "The job location GPS is available. You can navigate to the job now.",
        type: "gps_provided",
        bookingId: booking._id,
      });

      if (provider && provider.fcmToken) {
        await sendPush(
          provider.fcmToken,
          "GPS Location Ready",
          "Tap to navigate to the job location.",
          { bookingId: booking._id.toString(), type: "gps_provided" }
        );
      }
    } else {
      // GPS pending — ask seeker to share location
      await Notification.create({
        user: booking.seeker,
        title: "Booking Accepted — Share Location",
        message:
          "Your booking was accepted! Please provide the exact GPS location of the job site so the provider can navigate there.",
        type: "gps_required",
        bookingId: booking._id,
      });

      if (seeker && seeker.fcmToken) {
        await sendPush(
          seeker.fcmToken,
          "📍 Share Job Location",
          "Your booking is accepted. Please share the GPS location of the job.",
          { bookingId: booking._id.toString(), type: "gps_required" }
        );
      }
    }
    // ─────────────────────────────────────────────────────────────────────────

    res.json(booking);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// ── NEW: Seeker submits GPS for a booking ─────────────────────────────────────
exports.submitJobGps = async (req, res) => {
  try {
    const { lat, lng, saveAsHome } = req.body;

    if (lat == null || lng == null) {
      return res.status(400).json({ message: "lat and lng are required" });
    }

    const booking = await Booking.findById(req.params.id);

    if (!booking) {
      return res.status(404).json({ message: "Booking not found" });
    }

    // Only the seeker of this booking can submit GPS
    if (booking.seeker.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: "Not authorized" });
    }

    if (booking.status !== "accepted") {
      return res
        .status(400)
        .json({ message: "GPS can only be submitted for accepted bookings" });
    }

    // Save GPS on booking
    booking.jobGpsLocation = { lat, lng };
    booking.gpsLocationStatus = "provided";
    await booking.save();

    // Optionally save as seeker's home GPS
    if (saveAsHome === true) {
      await User.findByIdAndUpdate(req.user._id, {
        homeGpsLocation: { lat, lng },
      });
    }

    // Notify the provider that GPS is now available
    const provider = await User.findById(booking.provider);

    await Notification.create({
      user: booking.provider,
      title: "GPS Location Shared",
      message: "The seeker has shared the exact job location. Tap to navigate.",
      type: "gps_provided",
      bookingId: booking._id,
    });

    if (provider && provider.fcmToken) {
      await sendPush(
        provider.fcmToken,
        "📍 Job Location Shared",
        "The seeker shared GPS for the job. Tap to navigate.",
        { bookingId: booking._id.toString(), type: "gps_provided" }
      );
    }

    res.json({ message: "GPS location saved", booking });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
// ─────────────────────────────────────────────────────────────────────────────

// ── NEW: Seeker skips GPS sharing ─────────────────────────────────────────────
exports.skipJobGps = async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);

    if (!booking) {
      return res.status(404).json({ message: "Booking not found" });
    }

    if (booking.seeker.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: "Not authorized" });
    }

    if (booking.status !== "accepted") {
      return res.status(400).json({ message: "Booking is not accepted" });
    }

    booking.gpsLocationStatus = "skipped";
    await booking.save();

    res.json({ message: "GPS skipped", booking });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
// ─────────────────────────────────────────────────────────────────────────────

exports.rejectBooking = async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);

    if (!booking) {
      return res.status(404).json({ message: "Booking not found" });
    }

    if (booking.provider.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: "Not authorized" });
    }

    if (booking.status !== "requested") {
      return res.status(400).json({ message: "Booking cannot be rejected" });
    }

    booking.status = "rejected";
    await booking.save();

    await Notification.create({
      user: booking.seeker,
      title: "Booking Rejected",
      message: "Your booking was rejected",
      type: "booking_rejected",
      bookingId: booking._id,
    });

    const seeker = await User.findById(booking.seeker);

    if (seeker && seeker.fcmToken) {
      await sendPush(
        seeker.fcmToken,
        "Booking Rejected",
        "Your booking was rejected",
        { bookingId: booking._id.toString(), type: "booking_rejected" }
      );
    }

    res.json(booking);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.completeBooking = async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);

    if (!booking) {
      return res.status(404).json({ message: "Booking not found" });
    }

    if (booking.provider.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: "Not authorized" });
    }

    if (booking.status !== "accepted") {
      return res
        .status(400)
        .json({ message: "Only accepted bookings can be completed" });
    }

    booking.status = "completed";
    await booking.save();

    await Notification.create({
      user: booking.seeker,
      title: "Booking Completed",
      message: "Your booking was completed",
      type: "booking_completed",
      bookingId: booking._id,
    });

    const seeker = await User.findById(booking.seeker);

    if (seeker && seeker.fcmToken) {
      await sendPush(
        seeker.fcmToken,
        "Booking Completed",
        "Your booking was completed",
        { bookingId: booking._id.toString(), type: "booking_completed" }
      );
    }

    res.json(booking);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.cancelBooking = async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);

    if (!booking) {
      return res.status(404).json({ message: "Booking not found" });
    }

    if (booking.seeker.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: "Not authorized" });
    }

    if (!["requested", "accepted"].includes(booking.status)) {
      return res.status(400).json({
        message: "Booking cannot be cancelled",
      });
    }

    booking.status = "cancelled";
    await booking.save();

    res.json(booking);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.getOccupiedRange = async (req, res) => {
  try {
    const { skillId } = req.params;

    const bookings = await Booking.find({
      skill: skillId,
      status: { $in: ["accepted", "in_progress"] },
    }).select("startDate endDate");

    const blocks = await BlockedSlot.find({
      skill: skillId,
    }).select("startDate endDate");

    const combined = [
      ...bookings.map((b) => ({
        startDate: b.startDate,
        endDate: b.endDate,
        type: "booking",
      })),
      ...blocks.map((b) => ({
        startDate: b.startDate,
        endDate: b.endDate,
        type: "blocked",
      })),
    ];

    res.json(combined);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

exports.toggleBlockedSlot = async (req, res) => {
  try {
    const { skillId, startDate, endDate, reason } = req.body;

    if (!skillId || !startDate || !endDate) {
      return res
        .status(400)
        .json({ message: "skillId, startDate and endDate are required" });
    }

    const skill = await Skill.findById(skillId);

    if (!skill) {
      return res.status(404).json({ message: "Skill not found" });
    }

    if (skill.provider.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: "Not authorized" });
    }

    const start = new Date(startDate);
    const end = new Date(endDate);

    if (isNaN(start.getTime()) || isNaN(end.getTime()) || start >= end) {
      return res.status(400).json({ message: "Invalid date range" });
    }

    const existing = await BlockedSlot.findOne({
      provider: req.user._id,
      skill: skillId,
      startDate: { $lt: end },
      endDate: { $gt: start },
    });

    if (existing) {
      await existing.deleteOne();
      return res.json({ message: "Slot unblocked" });
    }

    const blocked = await BlockedSlot.create({
      provider: req.user._id,
      skill: skillId,
      startDate: start,
      endDate: end,
      reason,
    });

    res.status(201).json(blocked);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
