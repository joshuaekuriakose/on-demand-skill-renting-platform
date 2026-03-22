const express = require("express");
const router  = express.Router();
const { protect } = require("../middleware/auth.middleware");
const {
  // Booking chat
  getChatList,
  getTotalUnread,
  getMessages,
  sendMessage,
  getUnreadCount,
  // Direct chat
  startDirectChat,
  getDirectMessages,
  sendDirectMessage,
  getDirectUnreadCount,
} = require("../controllers/message.controller");

// ── Unified chat list & totals ────────────────────────────────────────────────
router.get("/",             protect, getChatList);
router.get("/unread-total", protect, getTotalUnread);

// ── Direct (non-booking) chat ─────────────────────────────────────────────────
// NOTE: These must come BEFORE /:bookingId to avoid the wildcard swallowing them.
router.post("/direct",                               protect, startDirectChat);
router.get( "/direct/:conversationId",               protect, getDirectMessages);
router.post("/direct/:conversationId",               protect, sendDirectMessage);
router.get( "/direct/:conversationId/unread-count",  protect, getDirectUnreadCount);

// ── Booking chat ──────────────────────────────────────────────────────────────
router.get( "/:bookingId",              protect, getMessages);
router.post("/:bookingId",              protect, sendMessage);
router.get( "/:bookingId/unread-count", protect, getUnreadCount);

module.exports = router;
