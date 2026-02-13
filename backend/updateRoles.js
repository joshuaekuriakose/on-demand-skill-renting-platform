const mongoose = require("mongoose");
require("dotenv").config();

async function updateRoles() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log("✅ Connected to MongoDB");

    const result = await mongoose.connection.db.collection("users").updateMany(
      { role: { $in: ["seeker", "provider", "both"] } },
      { $set: { role: "user" } }
    );

    console.log(`✅ Updated ${result.modifiedCount} users`);
    console.log(`   Matched: ${result.matchedCount}`);
    
  } catch (error) {
    console.error("❌ Error:", error.message);
  } finally {
    await mongoose.disconnect();
    console.log("🔌 Disconnected from MongoDB");
    process.exit(0);
  }
}

updateRoles();