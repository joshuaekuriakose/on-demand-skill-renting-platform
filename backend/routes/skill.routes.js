const express = require("express");
const router = express.Router();
const { protect } = require("../middleware/auth.middleware");
const Skill = require("../models/Skill");

// Create skill (provider only)
router.post("/", protect, async (req, res) => {
  try {
    if (req.user.role !== "provider" && req.user.role !== "both") {
      return res.status(403).json({ message: "Only providers can add skills" });
    }

    const skill = await Skill.create({
      provider: req.user._id,
      ...req.body,
    });

    res.status(201).json(skill);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
