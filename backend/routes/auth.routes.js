const express = require("express");
const router = express.Router();

const {
  registerUser,
  loginUser,
  changePassword,
} = require("../controllers/auth.controller");

const { protect } = require("../middleware/auth.middleware");

router.post("/register", registerUser);
router.post("/login", loginUser);

router.put("/change-password", protect, changePassword);

module.exports = router;


/*router.get("/", (req, res) => {
  res.json({ message: "Auth route working" });
});*/