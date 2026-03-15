const express = require("express");
const cors    = require("cors");

const app = express();

app.use(cors());
app.use(express.json());

app.get("/", (req, res) => {
  res.send("API running successfully");
});

// Routes
const authRoutes         = require("./routes/auth.routes");
const skillRoutes        = require("./routes/skill.routes");
const bookingRoutes      = require("./routes/booking.routes");
const reviewRoutes       = require("./routes/review.routes");
const userRoutes         = require("./routes/user.routes");
const utilsRoutes        = require("./routes/utils.routes");
const notificationRoutes = require("./routes/notification.routes");
const reportRoutes       = require("./routes/report.routes");

app.use("/api/auth",          authRoutes);
app.use("/api/skills",        skillRoutes);
app.use("/api/bookings",      bookingRoutes);
app.use("/api/reviews",       reviewRoutes);
app.use("/api/users",         userRoutes);
app.use("/api/utils",         utilsRoutes);
app.use("/api/notifications", notificationRoutes);
app.use("/api/reports",       reportRoutes);

// Start scheduled report generation
require("./utils/scheduler");

module.exports = app;
