const express = require("express");
const router = express.Router();
const { protect } = require("../middleware/auth.middleware");
const User = require("../models/User");

// Get my profile
router.get("/me", protect, async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select("-password");

    res.json(user);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Update profile
router.put("/me", protect, async (req, res) => {
  try {
    const { name, phone } = req.body;

    const user = await User.findById(req.user._id);

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    if (name) user.name = name;
    if (phone) user.phone = phone;

    await user.save();

    res.json({
      _id: user._id,
      name: user.name,
      email: user.email,
      phone: user.phone,
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});


// Become Provider (upgrade to both)
/*router.put("/become-provider", protect, async (req, res) => {
  try {

    const user = await User.findById(req.user._id);

    if (!user) {
      return res.status(404).json({
        message: "User not found",
      });
    }

    // Already provider
    if (user.role === "both") {
      return res.json({
        message: "Already provider",
        role: user.role,
      });
    }

    // Upgrade
    user.role = "both";
    await user.save();

    res.json({
      message: "Upgraded to provider",
      role: user.role,
    });

  } catch (err) {
    res.status(500).json({
      message: err.message,
    });
  }
});*/
router.put("/become-provider", protect, async (req, res) => {
  return res.status(400).json({
    message: "This feature is no longer available",
  });
});

module.exports = router;
