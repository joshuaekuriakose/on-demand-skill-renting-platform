/**
 * Run this ONCE to create the admin account:
 *   node scripts/create.admin.js
 *
 * PUT YOUR PASSWORD on the line marked below before running.
 */

require("dotenv").config();
const mongoose = require("mongoose");
const User     = require("../models/User");

const ADMIN_EMAIL    = "joshuakuriakose1712@gmail.com";
const ADMIN_NAME     = "Admin";
const ADMIN_PASSWORD = "admin123";

async function seed() {
  await mongoose.connect(process.env.MONGO_URI);

  const exists = await User.findOne({ email: ADMIN_EMAIL });
  if (exists) {
    if (exists.role !== "admin") {
      exists.role = "admin";
      await exists.save();
      console.log("Existing user promoted to admin.");
    } else {
      console.log("Admin already exists. Nothing to do.");
    }
    await mongoose.disconnect();
    return;
  }

  await User.create({
    name:     ADMIN_NAME,
    email:    ADMIN_EMAIL,
    phone:    "7356461514",
    password: ADMIN_PASSWORD,
    role:     "admin",
  });

  console.log("Admin created successfully.");
  await mongoose.disconnect();
}

seed().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
