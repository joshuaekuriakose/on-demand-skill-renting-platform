/**
 * cleanup_overdue_bookings.js
 *
 * ONE-TIME SCRIPT — run once from your backend folder to immediately cancel
 * all "requested" bookings whose slot start time has already passed
 * (i.e., all overdue test bookings and any real ones that slipped through).
 *
 * USAGE (from your backend directory):
 *   node utils/cleanup_overdue_bookings.js
 *
 * It connects to MongoDB using your existing .env MONGO_URI, cancels every
 * overdue requested booking, notifies seekers, then exits.
 */

require("dotenv").config();
const mongoose     = require("mongoose");
const Booking      = require("../models/Booking");
const User         = require("../models/User");
const Notification = require("../models/Notification");

async function run() {
  await mongoose.connect(process.env.MONGO_URI);
  console.log("Connected to MongoDB.");

  const now = new Date();

  // All "requested" bookings whose start time has already passed
  const overdue = await Booking.find({
    status:    "requested",
    startDate: { $lt: now },
  });

  console.log(`Found ${overdue.length} overdue requested booking(s) to cancel.`);

  for (const booking of overdue) {
    booking.status                     = "cancelled";
    booking.autoCancelledForNoResponse = true;
    booking.cancellationReason         =
      "Auto-cancelled: provider did not respond before the scheduled start time.";
    await booking.save();

    await Notification.create({
      user:      booking.seeker,
      title:     "Booking Auto-Cancelled",
      message:   "Your provider did not respond to your booking request in time. It has been cancelled automatically.",
      type:      "auto_cancelled",
      bookingId: booking._id,
    });

    console.log(`  ✓ Cancelled booking ${booking._id} (was scheduled for ${booking.startDate.toISOString()})`);
  }

  console.log("\nDone. All overdue bookings have been cancelled.");
  await mongoose.disconnect();
  process.exit(0);
}

run().catch((err) => {
  console.error("Error:", err.message);
  process.exit(1);
});
