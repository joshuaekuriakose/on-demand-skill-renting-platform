const express = require("express");
const router = express.Router();

const { protect } = require("../middleware/auth.middleware");
const Notification = require("../models/Notification");

// Get my notifications
router.get("/", protect, async (req, res) => {
  try {
    const data = await Notification.find({ user: req.user._id })
      .sort({ createdAt: -1 });

    res.json(data);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Mark as read
router.put("/:id/read", protect, async (req, res) => {
  try {
    const notif = await Notification.findById(req.params.id);

    if (!notif) {
      return res.status(404).json({ message: "Not found" });
    }

    if (notif.user.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: "Not allowed" });
    }

    notif.isRead = true;
    await notif.save();

    res.json(notif);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
