const express = require("express");
const router  = express.Router();
const { protect } = require("../middleware/auth.middleware");
const {
  generateCustomReport,
  getMyReports,
  getReportById,
} = require("../controllers/report.controller");

router.post("/generate",  protect, generateCustomReport); // custom date range
router.get("/",           protect, getMyReports);         // report history list
router.get("/:id",        protect, getReportById);        // full data for PDF

module.exports = router;
