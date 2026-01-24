const express = require("express");
const router = express.Router();
const { protect } = require("../middleware/auth.middleware");
const Booking = require("../models/Booking");
const Skill = require("../models/Skill");

// Create booking (seeker only, no self-booking)
router.post("/", protect, async (req, res) => {
  try {
    const { skillId, startDate, endDate, duration } = req.body;

    // Fetch skill
    const skill = await Skill.findById(skillId);
    if (!skill) {
      return res.status(404).json({ message: "Skill not found" });
    }

    // 🚫 Block self-booking
    if (skill.provider.toString() === req.user._id.toString()) {
      return res
        .status(400)
        .json({ message: "You cannot book your own skill" });
    }

    // Create booking with price snapshot
    const booking = await Booking.create({
      seeker: req.user._id,
      provider: skill.provider,
      skill: skill._id,
      startDate,
      endDate,
      duration,
      pricingSnapshot: {
        amount: skill.pricing.amount,
        unit: skill.pricing.unit,
      },
    });
    res.status(201).json(booking);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

    // Get bookings for logged-in seeker  
   router.get("/my", protect, async (req, res) => {
    try {         
      const bookings = await Booking.find({ seeker: req.user._id })          
      .populate("skill")
      .populate("provider", "name email");    
     
      res.status(200).json(bookings);    
    } catch (error) {         
      res.status(500).json({ message: error.message });     
    }  
   });

   // Get bookings for logged-in provider
   router.get("/provider", protect, async (req, res) => {  
    try {    
      const bookings = await Booking.find({ provider: req.user._id })     
      .populate("skill")
      .populate("seeker", "name email");
    
      res.status(200).json(bookings);  
    } catch (error) {    
      res.status(500).json({ message: error.message });  
    }
   });


    //Accept booking (provider only)
    router.put("/:id/accept", protect, async (req, res) => {
      try {
        const booking = await Booking.findById(req.params.id);
        
        if (!booking) {
          return res.status(404).json({ message: "Booking not found" });
        }

        // Only provider can accept
       if (booking.provider.toString() !== req.user._id.toString()) {
        return res.status(403).json({ message: "Not authorized" });
      }

      if (booking.status !== "requested") {
        return res
        .status(400)
        .json({ message: "Booking cannot be accepted" });
      }
      
      booking.status = "accepted";
      await booking.save();
      
      res.json(booking);
    } catch (error) {
      res.status(500).json({ message: error.message });
    }
   });

   // Reject booking (provider only)
   router.put("/:id/reject", protect, async (req, res) => {
    try {
      const booking = await Booking.findById(req.params.id);
      
      if (!booking) {
        return res.status(404).json({ message: "Booking not found" });
      }
      if (booking.provider.toString() !== req.user._id.toString()) {
        return res.status(403).json({ message: "Not authorized" });
      }
      if (booking.status !== "requested") {
        return res
        .status(400)
        .json({ message: "Booking cannot be rejected" });
      }
      booking.status = "rejected";
      await booking.save();
      res.json(booking);
    } catch (error) {
      res.status(500).json({ message: error.message });
    }
   });
  
   // Complete booking (provider only)

   router.put("/:id/complete", protect, async (req, res) => {  
    try {    
      const booking = await Booking.findById(req.params.id);
    
      if (!booking) {     
        return res.status(404).json({ message: "Booking not found" });   
      }
    
      if (booking.provider.toString() !== req.user._id.toString()) {      
        return res.status(403).json({ message: "Not authorized" });   
      }
    
      if (booking.status !== "accepted") {     
        return res      
        .status(400)
        .json({ message: "Only accepted bookings can be completed" });   
      }
   
      booking.status = "completed";   
      await booking.save();
   
      res.json(booking); 
    } catch (error) {   
      res.status(500).json({ message: error.message }); 
    }
   });


module.exports = router;
