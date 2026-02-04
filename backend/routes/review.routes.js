const express = require("express");
const router = express.Router();
const { protect } = require("../middleware/auth.middleware");
const Review = require("../models/Review");
const Booking = require("../models/Booking");
const Skill = require("../models/Skill");
const User = require("../models/User");

// Create review (seeker only, after completion)
router.post("/", protect, async (req, res) => {
  try {
    const { bookingId, rating, comment } = req.body;

    const booking = await Booking.findById(bookingId);
    if (!booking) {
      return res.status(404).json({ message: "Booking not found" });
    }

    // Only seeker can review
    if (booking.seeker.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: "Not authorized to review" });
    }

    // Booking must be completed
    if (booking.status !== "completed") {
      return res
        .status(400)
        .json({ message: "Only completed bookings can be reviewed" });
    }

    // Prevent duplicate review
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

    // Mark booking as reviewed
booking.isReviewed = true;
await booking.save();


    /* =======================
       UPDATE AGGREGATE RATINGS
    ======================= */

    // Update provider rating
    const providerReviews = await Review.find({ provider: booking.provider });
    const providerAvg =
      providerReviews.reduce((sum, r) => sum + r.rating, 0) /
      providerReviews.length;

    await User.findByIdAndUpdate(booking.provider, {
      rating: providerAvg,
      totalReviews: providerReviews.length,
    });

    // Update skill rating
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

module.exports = router;
