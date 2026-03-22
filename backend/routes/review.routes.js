const express = require("express");
const router = express.Router();
const { protect } = require("../middleware/auth.middleware");
const Review = require("../models/Review");
const Booking = require("../models/Booking");
const Skill = require("../models/Skill");
const User = require("../models/User");

// ── Create review (seeker only, after completion) ─────────────────────────────
router.post("/", protect, async (req, res) => {
  try {
    const { bookingId, rating, comment } = req.body;

    const booking = await Booking.findById(bookingId);
    if (!booking) {
      return res.status(404).json({ message: "Booking not found" });
    }

    if (booking.seeker.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: "Not authorized to review" });
    }

    // Allow review on completed bookings OR auto-cancelled (no-response) bookings
    const isCompleted     = booking.status === "completed";
    const isAutoCancelled = booking.status === "cancelled" &&
                            booking.autoCancelledForNoResponse === true;

    if (!isCompleted && !isAutoCancelled) {
      return res
        .status(400)
        .json({ message: "Only completed or auto-cancelled bookings can be reviewed" });
    }

    const existingReview = await Review.findOne({ booking: bookingId });
    if (existingReview) {
      return res.status(400).json({ message: "Review already submitted" });
    }

    const review = await Review.create({
      booking: bookingId,
      reviewer: booking.seeker,
      provider: booking.provider,
      skill: booking.skill,
      rating,
      comment,
    });

    booking.isReviewed = true;
    await booking.save();

    // Update provider aggregate rating
    const providerReviews = await Review.find({ provider: booking.provider });
    const providerAvg =
      providerReviews.reduce((sum, r) => sum + r.rating, 0) /
      providerReviews.length;
    await User.findByIdAndUpdate(booking.provider, {
      rating: providerAvg,
      totalReviews: providerReviews.length,
    });

    // Update skill aggregate rating
    const skillReviews = await Review.find({ skill: booking.skill });
    const skillAvg =
      skillReviews.reduce((sum, r) => sum + r.rating, 0) /
      skillReviews.length;
    await Skill.findByIdAndUpdate(booking.skill, {
      rating: skillAvg,
      totalReviews: skillReviews.length,
    });

    res.status(201).json(review);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// ── Get reviews for a skill (public — includes providerReply) ─────────────────
router.get("/skill/:id", async (req, res) => {
  try {
    const reviews = await Review.find({
      skill: req.params.id,
      isVisible: true,
    })
      .populate("reviewer", "name")
      .sort({ createdAt: -1 });

    res.json(reviews);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ── Provider reply to a review ────────────────────────────────────────────────
// PUT /reviews/:id/reply
// Only the provider who owns the skill can reply; replaces existing reply
router.put("/:id/reply", protect, async (req, res) => {
  try {
    const { text } = req.body;

    if (!text || !text.trim()) {
      return res.status(400).json({ message: "Reply text is required" });
    }

    const review = await Review.findById(req.params.id);
    if (!review) {
      return res.status(404).json({ message: "Review not found" });
    }

    // Only the provider linked to this review can reply
    if (review.provider.toString() !== req.user._id.toString()) {
      return res
        .status(403)
        .json({ message: "Not authorised to reply to this review" });
    }

    review.providerReply = {
      text: text.trim(),
      repliedAt: new Date(),
    };
    await review.save();

    res.json(review);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ── Delete provider reply ─────────────────────────────────────────────────────
// DELETE /reviews/:id/reply
router.delete("/:id/reply", protect, async (req, res) => {
  try {
    const review = await Review.findById(req.params.id);
    if (!review) {
      return res.status(404).json({ message: "Review not found" });
    }

    if (review.provider.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: "Not authorised" });
    }

    review.providerReply = { text: null, repliedAt: null };
    await review.save();

    res.json({ message: "Reply deleted" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
