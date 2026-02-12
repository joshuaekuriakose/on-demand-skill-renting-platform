const express = require("express");
const router = express.Router();
const {
  registerUser,
  loginUser,
} = require("../controllers/auth.controller");

router.post("/register", registerUser);
router.post("/login", loginUser);

/*router.get("/", (req, res) => {
  res.json({ message: "Auth route working" });
});*/


module.exports = router;
