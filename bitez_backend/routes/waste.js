const router      = require('express').Router();
const WasteRecord = require('../models/WasteRecord');
const FridgeItem  = require('../models/FridgeItem');
const auth        = require('../middleware/authMiddleware');

// All waste routes require authentication
router.use(auth);

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/waste
// Records a discarded food item and optionally removes it from user's fridge
// ─────────────────────────────────────────────────────────────────────────────
router.post('/', async (req, res, next) => {
  try {
    const {
      foodItemId,
      foodName,
      category,
      quantity = 1,
      unit = 'item',
      reason = 'Expired',
      estimatedCost = 2.0,
    } = req.body;

    if (!foodName || !foodName.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Food name is required to log waste.',
      });
    }

    const record = await WasteRecord.create({
      userId: req.user.id,
      foodItemId: foodItemId || null,
      foodName: foodName.trim(),
      category: category || 'Other',
      quantity: Number(quantity) || 1,
      unit: unit || 'item',
      reason: reason || 'Expired',
      estimatedCost: Number(estimatedCost) || 2.0,
      date: new Date(),
    });

    // If a foodItemId was associated, remove or decrement it from FridgeItem
    if (foodItemId) {
      try {
        const item = await FridgeItem.findOne({ _id: foodItemId, userId: req.user.id });
        if (item) {
          if (item.qty <= quantity) {
            await FridgeItem.deleteOne({ _id: foodItemId });
          } else {
            item.qty -= quantity;
            await item.save();
          }
        }
      } catch (err) {
        console.warn('Waste logging: Could not remove associated fridge item:', err.message);
      }
    }

    res.status(201).json({
      success: true,
      message: 'Food waste logged successfully.',
      record,
    });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/waste
// Retrieves user's waste logs in descending order
// ─────────────────────────────────────────────────────────────────────────────
router.get('/', async (req, res, next) => {
  try {
    const records = await WasteRecord.find({ userId: req.user.id })
      .sort({ date: -1 })
      .limit(100);

    res.json({
      success: true,
      count: records.length,
      records,
    });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/waste/stats
// Aggregates waste metrics: total wasted, category breakdown, reason breakdown,
// and avoidable waste percentage.
// ─────────────────────────────────────────────────────────────────────────────
router.get('/stats', async (req, res, next) => {
  try {
    const records = await WasteRecord.find({ userId: req.user.id }).sort({ date: -1 });

    let totalWastedItems = 0;
    let totalCostLost = 0.0;
    const reasonBreakdown = {};
    const categoryBreakdown = {};
    let avoidableCount = 0;

    const avoidableReasons = new Set(['Expired', 'Forgotten food', 'Excess quantity']);

    for (const r of records) {
      const q = Number(r.quantity) || 1;
      const c = Number(r.estimatedCost) || 2.0;

      totalWastedItems += q;
      totalCostLost += q * c;

      const reason = r.reason || 'Other';
      reasonBreakdown[reason] = (reasonBreakdown[reason] || 0) + q;

      const cat = r.category || 'Other';
      categoryBreakdown[cat] = (categoryBreakdown[cat] || 0) + q;

      if (avoidableReasons.has(reason)) {
        avoidableCount += q;
      }
    }

    const avoidablePercentage = totalWastedItems > 0
      ? Math.round((avoidableCount / totalWastedItems) * 100)
      : 0;

    res.json({
      success: true,
      stats: {
        totalWastedCount: records.length,
        totalWastedItems,
        totalCostLost: Number(totalCostLost.toFixed(2)),
        reasonBreakdown,
        categoryBreakdown,
        avoidablePercentage,
        recentRecords: records.slice(0, 10),
      },
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
