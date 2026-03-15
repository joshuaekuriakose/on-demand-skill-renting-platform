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

// ── Utility ────────────────────────────────────────────────────────────────────
function generateOtp() {
  return Math.floor(1000 + Math.random() * 9000).toString();
}

// ── Create Booking ─────────────────────────────────────────────────────────────
exports.createBooking = async (req, res) => {
  try {
    const { skillId, startDate, endDate, duration, jobAddress, jobDescription } = req.body;

    const skill = await Skill.findById(skillId);
    if (!skill) return res.status(404).json({ message: "Skill not found" });

    const unit = skill?.pricing?.unit;
    if (!unit) return res.status(400).json({ message: "Skill pricing unit is missing" });

    if (skill.provider.toString() === req.user._id.toString())
      return res.status(400).json({ message: "You cannot book your own skill" });

    if (!startDate || !endDate)
      return res.status(400).json({ message: "Start and end date are required" });

    if (!jobDescription || !jobDescription.trim())
      return res.status(400).json({ message: "Description is required" });

    const newStart = new Date(startDate);
    const newEnd = new Date(endDate);
    if (isNaN(newStart.getTime()) || isNaN(newEnd.getTime()))
      return res.status(400).json({ message: "Invalid date format" });

    let normalizedStart = newStart;
    let normalizedEnd = newEnd;

    if (unit === "day" || unit === "daily") {
      normalizedStart = new Date(newStart);
      normalizedStart.setHours(0, 0, 0, 0);
      normalizedEnd = new Date(newEnd);
      normalizedEnd.setHours(0, 0, 0, 0);
    }

    if (normalizedStart.getTime() >= normalizedEnd.getTime())
      return res.status(400).json({ message: "End date must be after start date" });

    const overlappingBooking = await Booking.findOne({
      skill: skill._id,
      status: { $in: ["accepted", "in_progress"] },
      startDate: { $lt: normalizedEnd },
      endDate: { $gt: normalizedStart },
    });
    if (overlappingBooking)
      return res.status(400).json({ message: "This date is already booked" });

    const existingPending = await Booking.findOne({
      seeker: req.user._id,
      skill: skill._id,
      status: "requested",
      startDate: { $lt: normalizedEnd },
      endDate: { $gt: normalizedStart },
    });
    if (existingPending)
      return res.status(400).json({ message: "Already request pending" });

    const providerUser = await User.findById(skill.provider);

    let enrichedJobAddress;
    if (jobAddress) {
      const validated = await validateAndEnrichAddress(jobAddress);
      if (!validated.ok) return res.status(400).json({ message: validated.message });
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
      pricingSnapshot: { amount: skill.pricing.amount, unit: skill.pricing.unit },
    });

    await Notification.create({
      user: skill.provider,
      title: "New Booking Request",
      message: "Someone requested your skill: " + skill.title,
      type: "new_request",
      bookingId: booking._id,
    });

    const provider = await User.findById(skill.provider);
    if (provider?.fcmToken) {
      await sendPush(provider.fcmToken, "New Booking", "Someone booked your skill", {
        type: "new_request",
        bookingId: booking._id.toString(),
      });
    }

    res.status(201).json(booking);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// ── Occupied slots ─────────────────────────────────────────────────────────────
exports.getOccupiedSlots = async (req, res) => {
  try {
    const { skillId } = req.params;
    const { date } = req.query;

    if (!date) return res.status(400).json({ message: "Date query parameter is required" });

    const startOfDay = new Date(date);
    const endOfDay = new Date(date);
    if (isNaN(startOfDay) || isNaN(endOfDay))
      return res.status(400).json({ message: "Invalid date format" });

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
      ...bookings.map((b) => ({ startDate: b.startDate, endDate: b.endDate, type: "booking" })),
      ...blocks.map((b)   => ({ startDate: b.startDate, endDate: b.endDate, type: "blocked" })),
    ];

    res.json(combined);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// ── Get my bookings (seeker) ───────────────────────────────────────────────────
// Populates provider with address + rating so seeker detail sheet can show them
exports.getMyBookings = async (req, res) => {
  try {
    const bookings = await Booking.find({ seeker: req.user._id })
      .populate("skill")
      .populate("provider", "name email address rating totalReviews");

    res.status(200).json(bookings);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// ── Get provider bookings ──────────────────────────────────────────────────────
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

// ── Accept booking ─────────────────────────────────────────────────────────────
exports.acceptBooking = async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking) return res.status(404).json({ message: "Booking not found" });
    if (booking.provider.toString() !== req.user._id.toString())
      return res.status(403).json({ message: "Not authorized" });
    if (booking.status !== "requested")
      return res.status(400).json({ message: "Booking cannot be accepted" });

    booking.status = "accepted";
    await booking.save();

    // Auto-reject conflicting requests
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
            message: "Your booking request was rejected because another request was accepted for the same slot.",
            type: "booking_rejected",
            bookingId: b._id,
          });
          const seeker = await User.findById(b.seeker);
          if (seeker?.fcmToken) {
            await sendPush(seeker.fcmToken, "Booking Rejected", "Another request was accepted for the same slot", {
              type: "booking_rejected",
              bookingId: b._id.toString(),
            });
          }
        })
      );
    }

    await Notification.create({
      user: booking.seeker,
      title: "Booking Accepted",
      message: "Your booking was accepted",
      type: "booking_accepted",
      bookingId: booking._id,
    });

    const seeker = await User.findById(booking.seeker);
    if (seeker?.fcmToken) {
      await sendPush(seeker.fcmToken, "Booking Accepted", "Your booking was accepted", {
        type: "booking_accepted",
        bookingId: booking._id.toString(),
      });
    }

    // Auto-fill GPS if seeker has home GPS saved
    const seekerUser = seeker || (await User.findById(booking.seeker));
    if (seekerUser?.homeGpsLocation?.lat && booking.gpsLocationStatus === "pending") {
      booking.jobGpsLocation = seekerUser.homeGpsLocation;
      booking.gpsLocationStatus = "provided";
      await booking.save();
    }

    res.json(booking);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// ── Reject booking ─────────────────────────────────────────────────────────────
exports.rejectBooking = async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking) return res.status(404).json({ message: "Booking not found" });
    if (booking.provider.toString() !== req.user._id.toString())
      return res.status(403).json({ message: "Not authorized" });
    if (booking.status !== "requested")
      return res.status(400).json({ message: "Booking cannot be rejected" });

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
    if (seeker?.fcmToken) {
      await sendPush(seeker.fcmToken, "Booking Rejected", "Your booking was rejected", {
        type: "booking_rejected",
        bookingId: booking._id.toString(),
      });
    }

    res.json(booking);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// ── Cancel booking (seeker) ────────────────────────────────────────────────────
exports.cancelBooking = async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking) return res.status(404).json({ message: "Booking not found" });
    if (booking.seeker.toString() !== req.user._id.toString())
      return res.status(403).json({ message: "Not authorized" });
    if (!["requested", "accepted"].includes(booking.status))
      return res.status(400).json({ message: "Booking cannot be cancelled" });

    booking.status = "cancelled";
    await booking.save();

    res.json(booking);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// ── Old complete (kept for compatibility) ──────────────────────────────────────
exports.completeBooking = async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking) return res.status(404).json({ message: "Booking not found" });
    if (booking.provider.toString() !== req.user._id.toString())
      return res.status(403).json({ message: "Not authorized" });
    if (!["accepted", "in_progress"].includes(booking.status))
      return res.status(400).json({ message: "Cannot complete this booking" });

    booking.status = "completed";
    booking.totalAmount = booking.pricingSnapshot.amount + (booking.extraCharges || 0);
    await booking.save();

    await Notification.create({
      user: booking.seeker,
      title: "Booking Completed",
      message: "Your booking was completed",
      type: "booking_completed",
      bookingId: booking._id,
    });

    const seeker = await User.findById(booking.seeker);
    if (seeker?.fcmToken) {
      await sendPush(seeker.fcmToken, "Booking Completed", "Your booking was completed", {
        type: "booking_completed",
        bookingId: booking._id.toString(),
      });
    }

    res.json(booking);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// ══════════════════════════════════════════════════════════════════════════════
//  OTP FLOW
// ══════════════════════════════════════════════════════════════════════════════

// ── 1. Provider clicks "Begin" ─────────────────────────────────────────────────
// Generates beginOtp, stores on booking, notifies seeker (they see it on screen)
exports.beginBooking = async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking) return res.status(404).json({ message: "Booking not found" });
    if (booking.provider.toString() !== req.user._id.toString())
      return res.status(403).json({ message: "Not authorized" });
    if (booking.status !== "accepted")
      return res.status(400).json({ message: "Booking must be accepted to begin" });

    const otp = generateOtp();
    booking.beginOtp = otp;
    await booking.save();

    await Notification.create({
      user: booking.seeker,
      title: "Provider has arrived!",
      message: `Your provider is at your location. Share OTP ${otp} to begin the service.`,
      type: "begin_otp",
      bookingId: booking._id,
    });

    const seeker = await User.findById(booking.seeker);
    if (seeker?.fcmToken) {
      await sendPush(
        seeker.fcmToken,
        "Provider has arrived!",
        `Share OTP ${otp} with your provider to begin`,
        { type: "begin_otp", bookingId: booking._id.toString() }
      );
    }

    res.json(booking);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ── 2. Provider enters OTP seeker told them → status = in_progress ─────────────
exports.verifyBeginOtp = async (req, res) => {
  try {
    const { otp } = req.body;
    const booking = await Booking.findById(req.params.id);
    if (!booking) return res.status(404).json({ message: "Booking not found" });
    if (booking.provider.toString() !== req.user._id.toString())
      return res.status(403).json({ message: "Not authorized" });
    if (booking.status !== "accepted")
      return res.status(400).json({ message: "Invalid booking status" });
    if (!booking.beginOtp || booking.beginOtp !== otp)
      return res.status(400).json({ message: "Invalid OTP" });

    booking.status = "in_progress";
    booking.beginOtp = null;
    await booking.save();

    await Notification.create({
      user: booking.seeker,
      title: "Service Started",
      message: "Your service has started and is now in progress.",
      type: "service_started",
      bookingId: booking._id,
    });

    const seeker = await User.findById(booking.seeker);
    if (seeker?.fcmToken) {
      await sendPush(seeker.fcmToken, "Service Started", "Your service is now in progress", {
        type: "service_started",
        bookingId: booking._id.toString(),
      });
    }

    res.json(booking);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ── 3. Provider clicks "Complete" (optionally adds extra charges) ──────────────
// Generates completeOtp, notifies seeker
exports.requestComplete = async (req, res) => {
  try {
    const { extraCharges } = req.body; // optional, number
    const booking = await Booking.findById(req.params.id);
    if (!booking) return res.status(404).json({ message: "Booking not found" });
    if (booking.provider.toString() !== req.user._id.toString())
      return res.status(403).json({ message: "Not authorized" });
    if (booking.status !== "in_progress")
      return res.status(400).json({ message: "Booking must be in progress to complete" });

    const otp = generateOtp();
    booking.completeOtp = otp;
    booking.actualEndTime = new Date();

    if (extraCharges != null && Number(extraCharges) > 0) {
      booking.extraCharges = Number(extraCharges);
    }

    await booking.save();

    const base = booking.pricingSnapshot.amount;
    const extra = booking.extraCharges || 0;

    await Notification.create({
      user: booking.seeker,
      title: "Job Complete - Verify",
      message: `Provider has finished. Share OTP ${otp} to confirm completion. Total: ₹${base + extra}`,
      type: "complete_otp",
      bookingId: booking._id,
    });

    const seeker = await User.findById(booking.seeker);
    if (seeker?.fcmToken) {
      await sendPush(
        seeker.fcmToken,
        "Job Complete - Verify",
        `Share OTP ${otp} with provider to confirm`,
        { type: "complete_otp", bookingId: booking._id.toString() }
      );
    }

    res.json(booking);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ── 4. Provider enters completion OTP → status = completed, totalAmount set ─────
exports.verifyCompleteOtp = async (req, res) => {
  try {
    const { otp } = req.body;
    const booking = await Booking.findById(req.params.id);
    if (!booking) return res.status(404).json({ message: "Booking not found" });
    if (booking.provider.toString() !== req.user._id.toString())
      return res.status(403).json({ message: "Not authorized" });
    if (booking.status !== "in_progress")
      return res.status(400).json({ message: "Invalid booking status" });
    if (!booking.completeOtp || booking.completeOtp !== otp)
      return res.status(400).json({ message: "Invalid OTP" });

    const base = booking.pricingSnapshot.amount;
    const extra = booking.extraCharges || 0;

    booking.totalAmount = base + extra;
    booking.status = "completed";
    booking.completeOtp = null;
    await booking.save();

    await Notification.create({
      user: booking.seeker,
      title: "Service Completed",
      message: `Your service is complete. Total amount due: ₹${booking.totalAmount}`,
    });

    const seeker = await User.findById(booking.seeker);
    if (seeker?.fcmToken) {
      await sendPush(
        seeker.fcmToken,
        "Service Completed",
        `Total amount: ₹${booking.totalAmount}`
      );
    }

    res.json(booking);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ── Submit GPS (seeker) ────────────────────────────────────────────────────────
exports.submitJobGps = async (req, res) => {
  try {
    const { lat, lng, saveAsHome } = req.body;
    const booking = await Booking.findById(req.params.id);
    if (!booking) return res.status(404).json({ message: "Booking not found" });
    if (booking.seeker.toString() !== req.user._id.toString())
      return res.status(403).json({ message: "Not authorized" });

    booking.jobGpsLocation = { lat, lng };
    booking.gpsLocationStatus = "provided";
    await booking.save();

    if (saveAsHome) {
      await User.findByIdAndUpdate(req.user._id, { homeGpsLocation: { lat, lng } });
    }

    res.json(booking);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ── Skip GPS (seeker) ──────────────────────────────────────────────────────────
exports.skipJobGps = async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking) return res.status(404).json({ message: "Booking not found" });
    if (booking.seeker.toString() !== req.user._id.toString())
      return res.status(403).json({ message: "Not authorized" });

    booking.gpsLocationStatus = "skipped";
    await booking.save();
    res.json(booking);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ── Occupied slots ─────────────────────────────────────────────────────────────
exports.getOccupiedRange = async (req, res) => {
  try {
    const { skillId } = req.params;
    const bookings = await Booking.find({
      skill: skillId,
      status: { $in: ["accepted", "in_progress"] },
    }).select("startDate endDate");

    const blocks = await BlockedSlot.find({ skill: skillId }).select("startDate endDate");

    const combined = [
      ...bookings.map((b) => ({ startDate: b.startDate, endDate: b.endDate, type: "booking" })),
      ...blocks.map((b)   => ({ startDate: b.startDate, endDate: b.endDate, type: "blocked" })),
    ];

    res.json(combined);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// ── Toggle blocked slot ────────────────────────────────────────────────────────
exports.toggleBlockedSlot = async (req, res) => {
  try {
    const { skillId, startDate, endDate, reason } = req.body;
    if (!skillId || !startDate || !endDate)
      return res.status(400).json({ message: "skillId, startDate and endDate are required" });

    const skill = await Skill.findById(skillId);
    if (!skill) return res.status(404).json({ message: "Skill not found" });
    if (skill.provider.toString() !== req.user._id.toString())
      return res.status(403).json({ message: "Not authorized" });

    const start = new Date(startDate);
    const end = new Date(endDate);
    if (isNaN(start.getTime()) || isNaN(end.getTime()) || start >= end)
      return res.status(400).json({ message: "Invalid date range" });

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

// ── Mark Payment Done (dummy UPI flow) ─────────────────────────────────────────
exports.markPaymentDone = async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking) return res.status(404).json({ message: "Booking not found" });

    // Only the seeker who made the booking can mark it paid
    if (booking.seeker.toString() !== req.user._id.toString())
      return res.status(403).json({ message: "Not authorized" });

    if (booking.status !== "completed")
      return res.status(400).json({ message: "Booking is not completed yet" });

    if (booking.paymentStatus === "paid")
      return res.status(400).json({ message: "Already paid" });

    booking.paymentStatus = "paid";
    await booking.save();

    // Notify provider
    const provider = await User.findById(booking.provider);
    const seeker   = await User.findById(booking.seeker);

    await Notification.create({
      user:      booking.provider,
      title:     "Payment Received",
      message:   `${seeker?.name ?? "Seeker"} has completed payment of ₹${booking.totalAmount ?? booking.pricingSnapshot?.amount ?? 0}.`,
      bookingId: booking._id,
      type:      "payment",
    });

    if (provider?.fcmToken) {
      await sendPush(
        provider.fcmToken,
        "Payment Received 💰",
        `${seeker?.name ?? "Seeker"} paid ₹${booking.totalAmount ?? booking.pricingSnapshot?.amount ?? 0}.`,
        { bookingId: booking._id.toString(), type: "payment" }
      );
    }

    res.json({ message: "Payment marked as done", booking });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
