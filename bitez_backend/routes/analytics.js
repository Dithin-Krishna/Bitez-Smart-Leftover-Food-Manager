const router  = require('express').Router();
const CookLog = require('../models/CookLog');
const auth    = require('../middleware/authMiddleware');

// All analytics routes require authentication
router.use(auth);

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/analytics/waste-savings
// Aggregates food waste prevented, money saved, streak, and recent history.
// ─────────────────────────────────────────────────────────────────────────────
router.get('/waste-savings', async (req, res, next) => {
  try {
    const userId = req.user.id;

    // Fetch all logs for this user, sorted by most recent
    const logs = await CookLog.find({ userId }).sort({ cookedAt: -1 });

    const totalRecipesPrepared = logs.length;
    let totalLeftoversSaved = 0;
    let totalMoneySaved = 0;

    // Monthly tracking
    const now = new Date();
    const currentYear = now.getFullYear();
    const currentMonth = now.getMonth();

    let currentMonthSaved = 0;
    let currentMonthMoney = 0;
    const activeCookDates = new Set();
    const categoryCounts = {};

    for (const log of logs) {
      const items = Number(log.totalItemsSaved) || 0;
      const money = Number(log.estimatedMoneySaved) || 0;

      totalLeftoversSaved += items;
      totalMoneySaved += money;

      const logDate = new Date(log.cookedAt);
      const dateKey = logDate.toISOString().split('T')[0];

      if (logDate.getFullYear() === currentYear && logDate.getMonth() === currentMonth) {
        currentMonthSaved += items;
        currentMonthMoney += money;
        activeCookDates.add(dateKey);
      }

      // Aggregate category breakdown
      if (Array.isArray(log.deductions)) {
        for (const item of log.deductions) {
          const sec = (item.section || 'pantry').toLowerCase();
          categoryCounts[sec] = (categoryCounts[sec] || 0) + (Number(item.quantityUsed) || 1);
        }
      }
    }

    // Monthly Streak Days (number of unique days cooked this month)
    const monthlyStreakDays = activeCookDates.size;

    // Milestone / Progress Goal (e.g. 20 leftover items saved per month)
    const monthlyGoal = 20;
    const progressFraction = Math.min(1.0, currentMonthSaved / monthlyGoal);

    // Determine Badge Tier
    let streakBadge = 'Leftover Starter ⭐';
    if (monthlyStreakDays >= 10 || currentMonthSaved >= 25) {
      streakBadge = 'Zero-Waste Master 🏆';
    } else if (monthlyStreakDays >= 5 || currentMonthSaved >= 15) {
      streakBadge = 'Eco Chef 🔥';
    } else if (monthlyStreakDays >= 2 || currentMonthSaved >= 5) {
      streakBadge = 'Green Saver 🌱';
    }

    // Format recent 10 events
    const recentEvents = logs.slice(0, 10).map((log) => ({
      id: log._id.toString(),
      recipeTitle: log.recipeTitle,
      totalItemsSaved: log.totalItemsSaved,
      estimatedMoneySaved: Number(log.estimatedMoneySaved.toFixed(2)),
      cookedAt: log.cookedAt,
      deductions: log.deductions.map((d) => ({
        label: d.label,
        quantityUsed: d.quantityUsed,
        section: d.section,
      })),
    }));

    res.json({
      success: true,
      analytics: {
        totalRecipesPrepared,
        totalLeftoversSaved,
        totalMoneySaved: Number(totalMoneySaved.toFixed(2)),
        monthlyStreakDays,
        currentMonthSaved,
        currentMonthMoney: Number(currentMonthMoney.toFixed(2)),
        monthlyGoal,
        monthlyGoalProgress: Number(progressFraction.toFixed(2)),
        streakBadge,
        categoryCounts,
        recentEvents,
      },
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
