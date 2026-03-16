const express = require("express");
const router  = express.Router();
const { protect } = require("../middleware/auth.middleware");
const {
  getMessages,
  sendMessage,
  getUnreadCount,
} = require("../controllers/message.controller");

router.get( "/:bookingId",              protect, getMessages);
router.post("/:bookingId",              protect, sendMessage);
router.get( "/:bookingId/unread-count", protect, getUnreadCount);

module.exports = router;
