const express = require("express");
const router = express.Router();
const { protect } = require("../middleware/auth.middleware");

const {
  createBooking,
  getOccupiedSlots,
  getMyBookings,
  getProviderBookings,
  acceptBooking,
  rejectBooking,
  completeBooking,
  cancelBooking,
  getOccupiedRange,
  toggleBlockedSlot,
  submitJobGps,   // NEW
  skipJobGps,     // NEW
} = require("../controllers/booking.controller");

router.post("/", protect, createBooking);
router.get("/occupied/:skillId", protect, getOccupiedSlots);
router.get("/my", protect, getMyBookings);
router.get("/provider", protect, getProviderBookings);
router.put("/:id/accept", protect, acceptBooking);
router.put("/:id/reject", protect, rejectBooking);
router.put("/:id/complete", protect, completeBooking);
router.put("/:id/cancel", protect, cancelBooking);
router.get("/occupied-range/:skillId", protect, getOccupiedRange);
router.post("/blocks/toggle", protect, toggleBlockedSlot);

// ── GPS routes ─────────────────────────────────────────────────────────────
// Seeker submits GPS location for accepted booking
// Body: { lat: number, lng: number, saveAsHome: boolean }
router.put("/:id/gps", protect, submitJobGps);

// Seeker opts to skip GPS sharing
router.put("/:id/skip-gps", protect, skipJobGps);
// ──────────────────────────────────────────────────────────────────────────

module.exports = router;
