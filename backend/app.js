const express = require("express");
const cors = require("cors");

const app = express();

app.use(cors());
app.use(express.json());

app.get("/", (req, res) => {
  res.send("API running successfully");
});


const authRoutes = require("./routes/auth.routes");

app.use("/api/auth", authRoutes);

module.exports = app;


const skillRoutes = require("./routes/skill.routes");

app.use("/api/skills", skillRoutes);


const bookingRoutes = require("./routes/booking.routes");

app.use("/api/bookings", bookingRoutes);


app.use("/api/reviews", require("./routes/review.routes"));
