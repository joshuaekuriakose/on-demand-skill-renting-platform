const express = require("express");
const router  = express.Router();
const { adminOnly } = require("../middleware/admin.middleware");
const {
  getStats,
  getUsers,
  getUserDetail,
  getBookings,
  getRevenue,
  getBookingsBySkill,
  getBookingsForSkill,
  getDistricts,
  generateUserReport,
  generateProviderReport,
  generateBulkUserReport,
  generateBookingsReport,
} = require("../controllers/admin.controller");

router.get("/stats",                    adminOnly, getStats);
router.get("/users",                    adminOnly, getUsers);
router.get("/users/:id",                adminOnly, getUserDetail);
router.get("/bookings",                 adminOnly, getBookings);
router.get("/revenue",                  adminOnly, getRevenue);
router.get("/bookings/skills",          adminOnly, getBookingsBySkill);
router.get("/bookings/skill/:skillId",  adminOnly, getBookingsForSkill);
router.get("/districts",                adminOnly, getDistricts);
router.post("/reports/user",            adminOnly, generateUserReport);
router.post("/reports/provider",        adminOnly, generateProviderReport);
router.post("/reports/bulk-users",      adminOnly, generateBulkUserReport);
router.post("/reports/bookings",        adminOnly, generateBookingsReport);

module.exports = router;
