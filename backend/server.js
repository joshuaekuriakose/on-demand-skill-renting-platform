const dotenv = require("dotenv");
dotenv.config();

const http      = require("http");
const { Server } = require("socket.io");
const app       = require("./app");
const connectDB = require("./config/db");

connectDB();

const server = http.createServer(app);

// ── Socket.io setup ───────────────────────────────────────────────────────────
const io = new Server(server, {
  cors: { origin: "*", methods: ["GET", "POST"] },
});

// Make io accessible in controllers via req.app.get("io")
app.set("io", io);

io.on("connection", (socket) => {
  // Client joins a room named "booking:<bookingId>"
  socket.on("join_booking", (bookingId) => {
    socket.join(`booking:${bookingId}`);
  });

  socket.on("leave_booking", (bookingId) => {
    socket.leave(`booking:${bookingId}`);
  });

  socket.on("disconnect", () => {});
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, "0.0.0.0", () => {
  console.log(`Server running on port ${PORT}`);
});
