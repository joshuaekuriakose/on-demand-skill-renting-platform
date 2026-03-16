const Message  = require("../models/Message");
const Booking  = require("../models/Booking");
const User     = require("../models/User");
const Notification = require("../models/Notification");
const sendPush = require("../utils/sendPush");

// ── Verify the requester is part of this booking ──────────────────────────────
async function getBookingAndRole(bookingId, userId) {
  const booking = await Booking.findById(bookingId).lean();
  if (!booking) return null;

  const seekerId   = booking.seeker.toString();
  const providerId = booking.provider.toString();
  const uid        = userId.toString();

  if (uid === seekerId)   return { booking, role: "seeker",   otherId: providerId };
  if (uid === providerId) return { booking, role: "provider", otherId: seekerId   };
  return null;
}

// ── GET /api/messages/:bookingId ──────────────────────────────────────────────
exports.getMessages = async (req, res) => {
  try {
    const info = await getBookingAndRole(req.params.bookingId, req.user._id);
    if (!info) return res.status(403).json({ message: "Not authorized" });

    // Only allow messaging on accepted / in_progress bookings
    const allowed = ["accepted", "in_progress", "completed"];
    if (!allowed.includes(info.booking.status))
      return res.status(400).json({ message: "Chat is only available for accepted bookings" });

    const messages = await Message.find({ booking: req.params.bookingId })
      .populate("sender", "name")
      .sort({ createdAt: 1 })
      .lean();

    // Mark unread messages sent by the other party as read
    await Message.updateMany(
      { booking: req.params.bookingId, sender: info.otherId, isRead: false },
      { $set: { isRead: true } }
    );

    res.json(messages);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ── POST /api/messages/:bookingId ─────────────────────────────────────────────
exports.sendMessage = async (req, res) => {
  try {
    const { text } = req.body;
    if (!text?.trim()) return res.status(400).json({ message: "Message text required" });

    const info = await getBookingAndRole(req.params.bookingId, req.user._id);
    if (!info) return res.status(403).json({ message: "Not authorized" });

    const allowed = ["accepted", "in_progress"];
    if (!allowed.includes(info.booking.status))
      return res.status(400).json({ message: "Chat is only available for accepted bookings" });

    const message = await Message.create({
      booking:    req.params.bookingId,
      sender:     req.user._id,
      senderRole: info.role,
      text:       text.trim(),
    });

    const populated = await Message.findById(message._id)
      .populate("sender", "name")
      .lean();

    // ── In-app notification + push to the other party ──────────────────────
    const other = await User.findById(info.otherId).lean();
    const senderName = req.user.name || "Someone";

    await Notification.create({
      user:      info.otherId,
      title:     `${senderName}`,
      message:   text.trim().length > 80 ? text.trim().substring(0, 80) + "…" : text.trim(),
      type:      "new_message",
      bookingId: req.params.bookingId,
    });

    if (other?.fcmToken) {
      await sendPush(
        other.fcmToken,
        `Message from ${senderName}`,
        text.trim().length > 80 ? text.trim().substring(0, 80) + "…" : text.trim(),
        {
          type:      "new_message",
          bookingId: req.params.bookingId.toString(),
        }
      );
    }

    // ── Emit via Socket.io to the booking room ─────────────────────────────
    // The Socket.io instance is attached to app in server.js
    const io = req.app.get("io");
    if (io) {
      io.to(`booking:${req.params.bookingId}`).emit("new_message", populated);
    }

    res.status(201).json(populated);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ── GET /api/messages/:bookingId/unread-count ─────────────────────────────────
exports.getUnreadCount = async (req, res) => {
  try {
    const info = await getBookingAndRole(req.params.bookingId, req.user._id);
    if (!info) return res.status(403).json({ message: "Not authorized" });

    const count = await Message.countDocuments({
      booking: req.params.bookingId,
      sender:  info.otherId,
      isRead:  false,
    });

    res.json({ count });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};
