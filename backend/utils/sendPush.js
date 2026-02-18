const admin = require("../config/firebase");

async function sendPush(token, title, body, data = {}) {
  if (!token) return;

  try {
    await admin.messaging().send({
      token,

      notification: {
        title,
        body,
      },

      data,
    });

    console.log("✅ Push sent");
  } catch (err) {
    console.error("❌ Push error:", err.message);
  }
}

module.exports = sendPush;