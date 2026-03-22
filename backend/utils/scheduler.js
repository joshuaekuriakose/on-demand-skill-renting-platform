const cron       = require("node-cron");
const { autoGenerate } = require("../controllers/report.controller");
const Booking    = require("../models/Booking");
const User       = require("../models/User");
const Notification = require("../models/Notification");
const sendPush   = require("../utils/sendPush");
// ── Date helpers ──────────────────────────────────────────────────────────────

function yesterday() {
  const d = new Date();
  d.setDate(d.getDate() - 1);
  return {
    from: new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0),
    to:   new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59),
  };
}

function lastWeek() {
  const now  = new Date();
  const day  = now.getDay();
  const diff = day === 0 ? 7 : day;
  const mon  = new Date(now);
  mon.setDate(now.getDate() - diff);
  mon.setHours(0, 0, 0, 0);
  const sun = new Date(mon);
  sun.setDate(mon.getDate() + 6);
  sun.setHours(23, 59, 59, 999);
  return { from: mon, to: sun };
}

function lastMonth() {
  const now  = new Date();
  const from = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const to   = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59);
  return { from, to };
}

// ── Report schedules ──────────────────────────────────────────────────────────

// Daily report for hourly providers — every day at 11:58 PM
cron.schedule("58 23 * * *", async () => {
  console.log("[Scheduler] Running daily report for hourly providers…");
  const { from, to } = yesterday();
  await autoGenerate({ type: "auto_daily", dateFrom: from, dateTo: to, pricingUnit: "hour" });
});

// Weekly report for daily providers — every Sunday at 11:59 PM
cron.schedule("59 23 * * 0", async () => {
  console.log("[Scheduler] Running weekly report for daily providers…");
  const { from, to } = lastWeek();
  await autoGenerate({ type: "auto_weekly", dateFrom: from, dateTo: to, pricingUnit: "day" });
});

// Monthly report for ALL providers — 1st of every month at midnight
cron.schedule("0 0 1 * *", async () => {
  console.log("[Scheduler] Running monthly report for all providers…");
  const { from, to } = lastMonth();
  await autoGenerate({ type: "auto_monthly", dateFrom: from, dateTo: to, pricingUnit: null });
});

// ── No-response auto-cancel — runs every minute ───────────────────────────────
//
// Three checkpoints, all for bookings still in "requested" status:
//
//   T-20 min → (UI only — provider phone shown on frontend, no server action)
//   T-10 min → send seeker a warning push: "Provider hasn't responded. You can withdraw."
//   T-5  min → auto-cancel + send seeker a push inviting them to review for non-response
//
// warningNotifiedAt prevents duplicate 10-min pushes for the same booking.

cron.schedule("* * * * *", async () => {
  try {
    const now = new Date();

    // ── 10-minute warning ─────────────────────────────────────────────────────
    // Window: startDate is between (now + 9min) and (now + 11min)
    // and warningNotifiedAt is null (not yet notified)
    const warnFrom = new Date(now.getTime() + 9  * 60 * 1000);
    const warnTo   = new Date(now.getTime() + 11 * 60 * 1000);

    const toWarn = await Booking.find({
      status:           "requested",
      startDate:        { $gte: warnFrom, $lte: warnTo },
      warningNotifiedAt: null,
    }).lean();

    for (const booking of toWarn) {
      // Mark warned first to prevent race condition on next tick
      await Booking.findByIdAndUpdate(booking._id, {
        $set: { warningNotifiedAt: now },
      });

      const seeker = await User.findById(booking.seeker).lean();

      await Notification.create({
        user:      booking.seeker,
        title:     "Provider hasn't responded yet",
        message:   "Your provider has not accepted your booking. Your slot is in about 10 minutes. You can withdraw your request now.",
        type:      "no_response_warning",
        bookingId: booking._id,
      });

      if (seeker?.fcmToken) {
        await sendPush(
          seeker.fcmToken,
          "Provider hasn't responded yet",
          "Your slot is in ~10 mins. You can withdraw your booking request.",
          { type: "no_response_warning", bookingId: booking._id.toString() }
        );
      }

      console.log(`[Scheduler] 10-min warning sent for booking ${booking._id}`);
    }

    // ── 5-minute auto-cancel ──────────────────────────────────────────────────
    // Window: startDate is between (now) and (now + 6min)
    // — catches any booking that made it past the warning and is now at the wire

    const cancelTo = new Date(now.getTime() + 6 * 60 * 1000);

    const toCancel = await Booking.find({
      status:    "requested",
      startDate: { $gte: now, $lte: cancelTo },
    }).lean();

    for (const booking of toCancel) {
      await Booking.findByIdAndUpdate(booking._id, {
        $set: {
          status:                    "cancelled",
          autoCancelledForNoResponse: true,
          cancellationReason:        "Auto-cancelled: provider did not respond before the slot.",
        },
      });

      const seeker = await User.findById(booking.seeker).lean();

      // Notification 1 — inform of cancellation
      await Notification.create({
        user:      booking.seeker,
        title:     "Booking Auto-Cancelled",
        message:   "Your booking was automatically cancelled because the provider did not respond before the scheduled slot.",
        type:      "auto_cancelled",
        bookingId: booking._id,
      });

      // Notification 2 — invite review for non-response
      await Notification.create({
        user:      booking.seeker,
        title:     "Rate the Provider's Responsiveness",
        message:   "Your booking was cancelled due to no response. Would you like to leave a review about this experience?",
        type:      "auto_cancel_review_invite",
        bookingId: booking._id,
      });

      if (seeker?.fcmToken) {
        await sendPush(
          seeker.fcmToken,
          "Booking Auto-Cancelled",
          "Provider didn't respond. Your booking has been cancelled.",
          { type: "auto_cancelled", bookingId: booking._id.toString() }
        );

        // Small delay between pushes so they appear separately
        await new Promise(r => setTimeout(r, 1500));

        await sendPush(
          seeker.fcmToken,
          "Leave a Review?",
          "Provider didn't respond to your request. Tap to rate this experience.",
          { type: "auto_cancel_review_invite", bookingId: booking._id.toString() }
        );
      }

      console.log(`[Scheduler] Auto-cancelled booking ${booking._id} (no provider response)`);
    }

    // ── Auto-complete bookings (hourly + daily) ─────────────────────────────
    // Rules:
    //   • Hourly:
    //       - If booking start is before noon => complete at today's 12:00
    //       - Else => complete 1 hour after booking's last slot end (endDate + 1h)
    //   • Daily:
    //       - Complete at 23:59:59.999 of the last booked day (endDate is exclusive)
    const baseMillisDay = 24 * 60 * 60 * 1000;
    const threeDaysAgo = new Date(now.getTime() - 3 * baseMillisDay);

    function completionTimeForHourly(booking) {
      const start = new Date(booking.startDate);
      const noon = new Date(start);
      noon.setHours(12, 0, 0, 0);
      if (start < noon) return noon;
      return new Date(new Date(booking.endDate).getTime() + 60 * 60 * 1000);
    }

    function completionTimeForDaily(booking) {
      // endDate is exclusive midnight of the day after the last slot day
      return new Date(new Date(booking.endDate).getTime() - 1);
    }

    const hourCandidates = await Booking.find({
      status: { $in: ["accepted", "in_progress"] },
      "pricingSnapshot.unit": "hour",
      startDate: { $lte: now, $gte: threeDaysAgo },
      endDate: { $ne: null },
    }).select("_id seeker startDate endDate pricingSnapshot extraCharges beginOtp completeOtp").lean();

    const dayCandidates = await Booking.find({
      status: { $in: ["accepted", "in_progress"] },
      "pricingSnapshot.unit": "day",
      endDate: { $ne: null, $lte: new Date(now.getTime() + 2 * baseMillisDay) },
    }).select("_id seeker startDate endDate pricingSnapshot extraCharges beginOtp completeOtp").lean();

    const candidates = [...hourCandidates, ...dayCandidates];

    for (const booking of candidates) {
      let completionAt = null;
      const unit = booking?.pricingSnapshot?.unit;
      if (unit === "hour") completionAt = completionTimeForHourly(booking);
      if (unit === "day") completionAt = completionTimeForDaily(booking);

      if (!completionAt || completionAt > now) continue;

      // Finalize the booking (no OTP flow required).
      const base = booking.pricingSnapshot.amount;
      const extra = booking.extraCharges || 0;
      const totalAmount = base + extra;

      await Booking.findByIdAndUpdate(booking._id, {
        $set: {
          status: "completed",
          actualEndTime: completionAt,
          totalAmount,
          beginOtp: null,
          completeOtp: null,
        },
      });

      // Notify seeker
      const seeker = await User.findById(booking.seeker).lean();
      await Notification.create({
        user: booking.seeker,
        title: "Booking Completed",
        message: "Your booking was completed automatically.",
        type: "booking_completed",
        bookingId: booking._id,
      });

      if (seeker?.fcmToken) {
        await sendPush(
          seeker.fcmToken,
          "Booking Completed",
          "Your booking was completed automatically.",
          { type: "booking_completed", bookingId: booking._id.toString() }
        );
      }
    }

  } catch (err) {
    console.error("[Scheduler] No-response check error:", err.message);
  }
});

console.log("[Scheduler] All cron jobs registered.");
