const { protect } = require("./auth.middleware");

const adminOnly = async (req, res, next) => {
  // First run the standard JWT check
  protect(req, res, async () => {
    if (req.user && req.user.role === "admin") {
      next();
    } else {
      res.status(403).json({ message: "Admin access required" });
    }
  });
};

module.exports = { adminOnly };
