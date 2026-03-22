const Message      = require("../models/Message");
const Booking      = require("../models/Booking");
const Conversation = require("../models/Conversation");
const User         = require("../models/User");
const sendPush     = require("../utils/sendPush");
const Notification = require("../models/Notification");

// ── Helper: verify requester is a participant of a booking ────────────────────
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

// ── Helper: verify requester is a participant of a conversation ───────────────
async function getConversationAndRole(conversationId, userId) {
  const conv = await Conversation.findById(conversationId)
    .populate("skill", "title")
    .lean();
  if (!conv) return null;

  const seekerId   = conv.seeker.toString();
  const providerId = conv.provider.toString();
  const uid        = userId.toString();

  if (uid === seekerId)   return { conv, role: "seeker",   otherId: providerId };
  if (uid === providerId) return { conv, role: "provider", otherId: seekerId   };
  return null;
}

// ════════════════════════════════════════════════════════════════════════════════
//  BOOKING CHAT
// ════════════════════════════════════════════════════════════════════════════════

// ── GET /api/messages/:bookingId ──────────────────────────────────────────────
exports.getMessages = async (req, res) => {
  try {
    const info = await getBookingAndRole(req.params.bookingId, req.user._id);
    if (!info) return res.status(403).json({ message: "Not authorized" });

    const allowed = ["accepted", "in_progress", "completed"];
    if (!allowed.includes(info.booking.status))
      return res.status(400).json({ message: "Chat is only available for accepted bookings" });

    const messages = await Message.find({ booking: req.params.bookingId })
      .populate("sender", "name")
      .sort({ createdAt: 1 })
      .lean();

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

    const other      = await User.findById(info.otherId).lean();
    const senderName = req.user.name || "Someone";
    const preview    = text.trim().length > 80 ? text.trim().substring(0, 80) + "…" : text.trim();

    if (other?.fcmToken) {
      await sendPush(
        other.fcmToken,
        `Message from ${senderName}`,
        preview,
        { type: "new_message", bookingId: req.params.bookingId.toString() }
      );
    }

    const io = req.app.get("io");
    if (io) io.to(`booking:${req.params.bookingId}`).emit("new_message", populated);

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

// ════════════════════════════════════════════════════════════════════════════════
//  DIRECT CHAT  (seeker → provider from Explore)
// ════════════════════════════════════════════════════════════════════════════════

// ── POST /api/messages/direct ─────────────────────────────────────────────────
// Seeker sends the first (or any subsequent) message to a provider.
// Creates the Conversation document on first send.
// Providers cannot call this — they reply via POST /direct/:conversationId.
exports.startDirectChat = async (req, res) => {
  try {
    const { providerId, text, skillId } = req.body;

    if (!providerId || !text?.trim())
      return res.status(400).json({ message: "providerId and text are required" });

    if (req.user._id.toString() === providerId)
      return res.status(400).json({ message: "You cannot message yourself" });

    const provider = await User.findById(providerId).lean();
    if (!provider) return res.status(404).json({ message: "Provider not found" });

    // Find or create the one conversation for this (seeker, provider) pair
    let conv = await Conversation.findOne({
      seeker:   req.user._id,
      provider: providerId,
    });

    if (!conv) {
      conv = await Conversation.create({
        seeker:   req.user._id,
        provider: providerId,
        skill:    skillId || null,
      });
    }

    const message = await Message.create({
      conversation: conv._id,
      sender:       req.user._id,
      senderRole:   "seeker",
      text:         text.trim(),
    });

    const populated = await Message.findById(message._id)
      .populate("sender", "name")
      .lean();

    const senderName = req.user.name || "Someone";
    const preview    = text.trim().length > 80 ? text.trim().substring(0, 80) + "…" : text.trim();

    await Notification.create({
      user:    providerId,
      title:   `Message from ${senderName}`,
      message: preview,
      type:    "new_direct_message",
    });

    if (provider.fcmToken) {
      await sendPush(
        provider.fcmToken,
        `Message from ${senderName}`,
        preview,
        { type: "new_direct_message", conversationId: conv._id.toString() }
      );
    }

    const io = req.app.get("io");
    if (io) io.to(`conversation:${conv._id}`).emit("new_message", populated);

    res.status(201).json({ conversationId: conv._id, message: populated });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ── GET /api/messages/direct/:conversationId ─────────────────────────────────
exports.getDirectMessages = async (req, res) => {
  try {
    const info = await getConversationAndRole(req.params.conversationId, req.user._id);
    if (!info) return res.status(403).json({ message: "Not authorized" });

    const messages = await Message.find({ conversation: req.params.conversationId })
      .populate("sender", "name")
      .sort({ createdAt: 1 })
      .lean();

    await Message.updateMany(
      { conversation: req.params.conversationId, sender: info.otherId, isRead: false },
      { $set: { isRead: true } }
    );

    res.json(messages);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ── POST /api/messages/direct/:conversationId ────────────────────────────────
// Both seeker and provider can send here.
// Provider can reply because the conversation was already created by the seeker.
exports.sendDirectMessage = async (req, res) => {
  try {
    const { text } = req.body;
    if (!text?.trim()) return res.status(400).json({ message: "Message text required" });

    const info = await getConversationAndRole(req.params.conversationId, req.user._id);
    if (!info) return res.status(403).json({ message: "Not authorized" });

    const message = await Message.create({
      conversation: req.params.conversationId,
      sender:       req.user._id,
      senderRole:   info.role,
      text:         text.trim(),
    });

    const populated = await Message.findById(message._id)
      .populate("sender", "name")
      .lean();

    const other      = await User.findById(info.otherId).lean();
    const senderName = req.user.name || "Someone";
    const preview    = text.trim().length > 80 ? text.trim().substring(0, 80) + "…" : text.trim();

    if (other?.fcmToken) {
      await sendPush(
        other.fcmToken,
        `Message from ${senderName}`,
        preview,
        { type: "new_direct_message", conversationId: req.params.conversationId.toString() }
      );
    }

    const io = req.app.get("io");
    if (io) io.to(`conversation:${req.params.conversationId}`).emit("new_message", populated);

    res.status(201).json(populated);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ── GET /api/messages/direct/:conversationId/unread-count ────────────────────
exports.getDirectUnreadCount = async (req, res) => {
  try {
    const info = await getConversationAndRole(req.params.conversationId, req.user._id);
    if (!info) return res.status(403).json({ message: "Not authorized" });

    const count = await Message.countDocuments({
      conversation: req.params.conversationId,
      sender:       info.otherId,
      isRead:       false,
    });

    res.json({ count });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ════════════════════════════════════════════════════════════════════════════════
//  UNIFIED CHAT LIST  +  TOTALS
// ════════════════════════════════════════════════════════════════════════════════

// ── GET /api/messages ─────────────────────────────────────────────────────────
// Returns only chats that have at least one message:
//   • Booking chats  — accepted / in_progress / completed bookings WITH ≥1 message
//   • Direct chats   — all conversations (always have ≥1 message by construction)
exports.getChatList = async (req, res) => {
  try {
    const userId = req.user._id;

    // ── 1. Booking chats ─────────────────────────────────────────────────────
    const allBookings = await Booking.find({
      $or: [{ seeker: userId }, { provider: userId }],
      status: { $in: ["accepted", "in_progress", "completed"] },
    })
      .populate("skill",    "title")
      .populate("seeker",   "name")
      .populate("provider", "name")
      .sort({ updatedAt: -1 })
      .lean();

    // Filter to only bookings that have at least one message
    const allBookingIds          = allBookings.map(b => b._id);
    const bookingIdsWithMessages = await Message.distinct("booking", {
      booking: { $in: allBookingIds },
    });
    const withMsgSet = new Set(bookingIdsWithMessages.map(String));
    const bookings   = allBookings.filter(b => withMsgSet.has(String(b._id)));

    const bookingItems = await Promise.all(bookings.map(async (b) => {
      const otherId = b.seeker._id.toString() === userId.toString()
        ? b.provider._id
        : b.seeker._id;

      const [latest, unread] = await Promise.all([
        Message.findOne({ booking: b._id }).sort({ createdAt: -1 }).lean(),
        Message.countDocuments({ booking: b._id, sender: otherId, isRead: false }),
      ]);

      return {
        chatId:          b._id.toString(),
        chatType:        "booking",
        skillTitle:      b.skill?.title || "Booking",
        otherPersonName: userId.toString() === b.seeker._id.toString()
          ? b.provider.name
          : b.seeker.name,
        status:      b.status,
        latestMessage: latest ? { text: latest.text, createdAt: latest.createdAt } : null,
        unreadCount:   unread,
      };
    }));

    // ── 2. Direct conversations ──────────────────────────────────────────────
    const conversations = await Conversation.find({
      $or: [{ seeker: userId }, { provider: userId }],
    })
      .populate("seeker",   "name")
      .populate("provider", "name")
      .populate("skill",    "title")
      .sort({ updatedAt: -1 })
      .lean();

    const directItems = await Promise.all(conversations.map(async (c) => {
      const isSeeker  = c.seeker._id.toString() === userId.toString();
      const otherId   = isSeeker ? c.provider._id : c.seeker._id;
      const otherName = isSeeker ? c.provider.name : c.seeker.name;

      const [latest, unread] = await Promise.all([
        Message.findOne({ conversation: c._id }).sort({ createdAt: -1 }).lean(),
        Message.countDocuments({ conversation: c._id, sender: otherId, isRead: false }),
      ]);

      if (!latest) return null; // skip empty conversations (defensive)

      return {
        chatId:          c._id.toString(),
        chatType:        "direct",
        skillTitle:      c.skill?.title || "Direct Message",
        otherPersonName: otherName || "User",
        status:          "direct",
        latestMessage:   { text: latest.text, createdAt: latest.createdAt },
        unreadCount:     unread,
      };
    }));

    // ── 3. Merge, drop nulls, sort by latest message ─────────────────────────
    const combined = [...bookingItems, ...directItems.filter(Boolean)];
    combined.sort((a, b) => {
      if (!a.latestMessage && !b.latestMessage) return 0;
      if (!a.latestMessage) return 1;
      if (!b.latestMessage) return -1;
      return new Date(b.latestMessage.createdAt) - new Date(a.latestMessage.createdAt);
    });

    res.json(combined);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// ── GET /api/messages/unread-total ────────────────────────────────────────────
// Total unread count across booking chats + direct conversations.
exports.getTotalUnread = async (req, res) => {
  try {
    const userId = req.user._id;
    let total = 0;

    // Booking chats
    const bookings = await Booking.find({
      $or: [{ seeker: userId }, { provider: userId }],
      status: { $in: ["accepted", "in_progress", "completed"] },
    }).lean();

    for (const b of bookings) {
      const otherId = b.seeker.toString() === userId.toString() ? b.provider : b.seeker;
      total += await Message.countDocuments({ booking: b._id, sender: otherId, isRead: false });
    }

    // Direct conversations
    const convs = await Conversation.find({
      $or: [{ seeker: userId }, { provider: userId }],
    }).lean();

    for (const c of convs) {
      const otherId = c.seeker.toString() === userId.toString() ? c.provider : c.seeker;
      total += await Message.countDocuments({ conversation: c._id, sender: otherId, isRead: false });
    }

    res.json({ count: total });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};
