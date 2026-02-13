const express = require("express");
const router = express.Router();
const { protect } = require("../middleware/auth.middleware");
const Skill = require("../models/Skill");

// Get all skills (public)
router.get("/", async (req, res) => {
  try {
    const skills = await Skill.find({ isActive: true })
      .populate("provider", "name email")
      .sort({ createdAt: -1 });

    res.json(skills);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Create skill (provider only)
router.post("/", protect, async (req, res) => {
  try {

    const skill = await Skill.create({
      provider: req.user._id,
      ...req.body,
    });

    res.status(201).json(skill);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Get my skills (provider only)
router.get("/my", protect, async (req, res) => {
  try {
    const skills = await Skill.find({ provider: req.user._id });
    res.json(skills);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Update skill (provider only)
router.put("/:id", protect, async (req, res) => {
  try {

    const skill = await Skill.findById(req.params.id);

    if (!skill) {
      return res.status(404).json({ message: "Skill not found" });
    }

    // Only owner can edit
    if (skill.provider.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: "Not authorized" });
    }

    Object.assign(skill, req.body);

    await skill.save();

    res.json(skill);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Delete skill (provider only)
router.delete("/:id", protect, async (req, res) => {
  try {

    const skill = await Skill.findById(req.params.id);

    if (!skill) {
      return res.status(404).json({ message: "Skill not found" });
    }

    if (skill.provider.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: "Not authorized" });
    }

    await skill.deleteOne();

    res.json({ message: "Skill deleted" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});



module.exports = router;
