const express = require("express");
const router = express.Router();

const { protect } = require("../middleware/auth.middleware");
const User = require("../models/User");


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
