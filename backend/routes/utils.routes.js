const express = require("express");
const router = express.Router();
const {
  normalizePin,
  lookupDistrictByPin,
  geocodePin,
} = require("../utils/pincode");

router.get("/pincode/:pin", async (req, res) => {
  try {
    const pin = normalizePin(req.params.pin);
    if (!pin) {
      return res.status(400).json({ message: "Invalid PIN code" });
    }

    const meta = await lookupDistrictByPin(pin);
    if (!meta) {
      return res.status(404).json({ message: "PIN code not found" });
    }

    const geo = await geocodePin(pin);

    res.json({
      pincode: pin,
      district: meta.district,
      state: meta.state,
      lat: geo?.lat,
      lon: geo?.lon,
    });
  } catch (e) {
    res.status(500).json({ message: e.message });
  }
});

module.exports = router;

