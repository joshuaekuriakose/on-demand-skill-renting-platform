const cron = require("node-cron");
const { autoGenerate } = require("../controllers/report.controller");

// ── Helpers ───────────────────────────────────────────────────────────────────

function yesterday() {
  const d = new Date();
  d.setDate(d.getDate() - 1);
  return {
    from: new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0),
    to:   new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59),
  };
}

function lastWeek() {
  const now  = new Date();
  const day  = now.getDay(); // 0=Sun
  const diff = day === 0 ? 7 : day;
  const mon  = new Date(now);
  mon.setDate(now.getDate() - diff);
  mon.setHours(0, 0, 0, 0);
  const sun = new Date(mon);
  sun.setDate(mon.getDate() + 6);
  sun.setHours(23, 59, 59, 999);
  return { from: mon, to: sun };
}

function lastMonth() {
  const now  = new Date();
  const from = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const to   = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59);
  return { from, to };
}

// ── Schedules ─────────────────────────────────────────────────────────────────

// Daily report for hourly providers — every day at 11:58 PM
cron.schedule("58 23 * * *", async () => {
  console.log("[Scheduler] Running daily report for hourly providers…");
  const { from, to } = yesterday();
  await autoGenerate({
    type:        "auto_daily",
    dateFrom:    from,
    dateTo:      to,
    pricingUnit: "hour",
  });
});

// Weekly report for daily providers — every Sunday at 11:59 PM
cron.schedule("59 23 * * 0", async () => {
  console.log("[Scheduler] Running weekly report for daily providers…");
  const { from, to } = lastWeek();
  await autoGenerate({
    type:        "auto_weekly",
    dateFrom:    from,
    dateTo:      to,
    pricingUnit: "day",
  });
});

// Monthly report for ALL providers — 1st of every month at midnight
cron.schedule("0 0 1 * *", async () => {
  console.log("[Scheduler] Running monthly report for all providers…");
  const { from, to } = lastMonth();
  await autoGenerate({
    type:        "auto_monthly",
    dateFrom:    from,
    dateTo:      to,
    pricingUnit: null, // all units
  });
});

console.log("[Scheduler] Report cron jobs registered.");
