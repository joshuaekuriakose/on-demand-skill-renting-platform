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
  beginBooking,
  verifyBeginOtp,
  requestComplete,
  verifyCompleteOtp,
  submitJobGps,
  skipJobGps,
} = require("../controllers/booking.controller");

router.post("/",                         protect, createBooking);
router.get("/occupied/:skillId",         protect, getOccupiedSlots);
router.get("/my",                        protect, getMyBookings);
router.get("/provider",                  protect, getProviderBookings);
router.get("/occupied-range/:skillId",   protect, getOccupiedRange);
router.post("/blocks/toggle",            protect, toggleBlockedSlot);

router.put("/:id/accept",               protect, acceptBooking);
router.put("/:id/reject",               protect, rejectBooking);
router.put("/:id/cancel",               protect, cancelBooking);
router.put("/:id/complete",             protect, completeBooking);   // legacy / fallback

// OTP flow
router.put("/:id/begin",                protect, beginBooking);       // provider triggers begin OTP
router.put("/:id/verify-begin",         protect, verifyBeginOtp);     // provider submits begin OTP → in_progress
router.put("/:id/request-complete",     protect, requestComplete);    // provider triggers complete OTP (+ optional extra charges)
router.put("/:id/verify-complete",      protect, verifyCompleteOtp);  // provider submits complete OTP → completed

// GPS
router.put("/:id/gps",                  protect, submitJobGps);
router.put("/:id/skip-gps",             protect, skipJobGps);

module.exports = router;
