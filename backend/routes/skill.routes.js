const express = require("express");
const router = express.Router();
const { protect, optionalAuth } = require("../middleware/auth.middleware");
const Skill = require("../models/Skill");
const Booking = require("../models/Booking");

// Get all skills (public — but excludes the logged-in user's own services)
router.get("/", optionalAuth, async (req, res) => {
  try {
    const filter = { isActive: true };

    // If the user is logged in, hide their own services from the list
    if (req.user) {
      filter.provider = { $ne: req.user._id };
    }

    const skills = await Skill.find(filter)
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

// Slots availability
router.get("/:id/available-slots", protect, async (req, res) => {
  try {
    const skillId = req.params.id;
    const date = req.query.date;

    const skill = await Skill.findById(skillId);
    const pricingUnit = skill.pricing.unit;

    // ── Daily ──────────────────────────────────────────────────────────────────
    if (pricingUnit === "day") {
      const today = new Date();
      const days = [];

      for (let i = 0; i < 30; i++) {
        const d = new Date();
        d.setDate(today.getDate() + i);

        const dayName = d
          .toLocaleDateString("en-US", { weekday: "long" })
          .toLowerCase();

        if (
          skill.availability.workingDays
            .map((w) => w.toLowerCase())
            .includes(dayName)
        ) {
          days.push(d.toISOString().split("T")[0]);
        }
      }

      return res.json({ availableSlots: days });
    }

    // ── Hourly ─────────────────────────────────────────────────────────────────
    if (pricingUnit === "hour") {
      if (!date) {
        return res.status(400).json({ message: "Date is required" });
      }

      const selectedDate = new Date(date);
      const dayName = selectedDate
        .toLocaleDateString("en-US", { weekday: "long" })
        .toLowerCase();

      if (
        !skill.availability.workingDays
          .map((w) => w.toLowerCase())
          .includes(dayName)
      ) {
        return res.json({ availableSlots: [] });
      }

      const { startTime, endTime, slotDuration } = skill.availability;
      const [startHour, startMinute] = startTime.split(":").map(Number);
      const [endHour, endMinute] = endTime.split(":").map(Number);

      let currentSlot = new Date(selectedDate);
      currentSlot.setHours(startHour, startMinute, 0, 0);

      const endOfDay = new Date(selectedDate);
      endOfDay.setHours(endHour, endMinute, 0, 0);

      const slots = [];
      while (currentSlot < endOfDay) {
        const isLunch =
          currentSlot.getHours() === 12 && currentSlot.getMinutes() === 30;
        if (!isLunch) {
          slots.push(currentSlot.toTimeString().slice(0, 5));
        }
        currentSlot = new Date(currentSlot.getTime() + slotDuration * 60000);
      }

      return res.json({ availableSlots: slots });
    }

    return res.status(400).json({ message: "Invalid pricing unit" });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
