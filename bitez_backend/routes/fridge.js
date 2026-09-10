const router     = require('express').Router();
const mongoose   = require('mongoose');
const FridgeItem = require('../models/FridgeItem');
const GroceryItem = require('../models/GroceryItem');
const CookLog    = require('../models/CookLog');
const auth       = require('../middleware/authMiddleware');

// All fridge routes require authentication
router.use(auth);

/**
 * Helper: Automatically adds an item to the Grocery List if its quantity drops to <= 1 or out of stock.
 */
async function autoCheckLowStockGrocery(userId, fridgeItem, customReason) {
  try {
    if (!fridgeItem) return;
    const isLow = fridgeItem.qty <= 1;
    if (!isLow && !customReason) return;

    const label = fridgeItem.label.trim();
    const existing = await GroceryItem.findOne({
      userId,
      label: { $regex: new RegExp(`^${label}$`, 'i') },
      isBought: false
    });

    if (!existing) {
      await GroceryItem.create({
        userId,
        label,
        emoji: fridgeItem.emoji || '🛒',
        qty: 1,
        section: fridgeItem.section || 'veggies',
        category: 'Produce',
        isBought: false,
        isAiSuggested: true,
        reason: customReason || (fridgeItem.qty === 0 ? 'Out of stock in fridge' : `Low stock in fridge (qty: ${fridgeItem.qty})`),
      });
    }
  } catch (err) {
    console.error('Error auto-adding low stock item to grocery list:', err.message);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/fridge
// Returns all fridge items for the logged-in user, grouped by section.
// Query param: ?section=frozen  (optional — filter by section)
// ─────────────────────────────────────────────────────────────────────────────
router.get('/', async (req, res, next) => {
  try {
    const filter = { userId: req.user.id };
    if (req.query.section) filter.section = req.query.section;

    const items = await FridgeItem.find(filter).sort({ section: 1, label: 1 });

    // Also return grouped structure for convenience
    const grouped = {};
    for (const item of items) {
      if (!grouped[item.section]) grouped[item.section] = [];
      grouped[item.section].push(item);
    }

    res.json({ success: true, count: items.length, items, grouped });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/fridge/expiry-summary
// Returns items with expiry dates and summary metrics (expired, expiring soon, fresh).
// ─────────────────────────────────────────────────────────────────────────────
router.get('/expiry-summary', async (req, res, next) => {
  try {
    const items = await FridgeItem.find({
      userId: req.user.id,
      expiresAt: { $ne: null }
    }).sort({ expiresAt: 1 });

    const now = new Date();
    const threeDaysFromNow = new Date();
    threeDaysFromNow.setDate(now.getDate() + 3);

    let expiredCount = 0;
    let expiringSoonCount = 0;
    let freshCount = 0;

    for (const item of items) {
      if (item.expiresAt < now) {
        expiredCount++;
      } else if (item.expiresAt <= threeDaysFromNow) {
        expiringSoonCount++;
      } else {
        freshCount++;
      }
    }

    res.json({
      success: true,
      summary: {
        totalTracked: items.length,
        expiredCount,
        expiringSoonCount,
        freshCount,
      },
      items,
    });
  } catch (err) {
    next(err);
  }
});

const { getDefaultShelfLifeDays } = require('../models/FoodCatalog');

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/fridge
// Add a single new item.
// Body: { emoji, label, qty, color, section, expiresAt?, manufacturingDate?, expiryImage?, expiryNotes? }
// ─────────────────────────────────────────────────────────────────────────────
router.post('/', async (req, res, next) => {
  try {
    const { emoji, label, qty, color, section, expiresAt, manufacturingDate, expiryImage, expiryNotes } = req.body;

    if (!emoji || !label || !section) {
      return res.status(400).json({
        success: false,
        message: 'emoji, label, and section are required.',
      });
    }

    // Auto-calculate default expiry date if none was explicitly provided
    let finalExpiresAt = expiresAt || null;
    if (!finalExpiresAt) {
      const days = getDefaultShelfLifeDays(label, section);
      finalExpiresAt = new Date(Date.now() + days * 24 * 60 * 60 * 1000);
    }

    const item = await FridgeItem.create({
      userId: req.user.id,
      emoji,
      label: label.trim(),
      qty:   qty   !== undefined ? Number(qty) : 1,
      color: color !== undefined ? Number(color) : undefined,
      section,
      expiresAt: finalExpiresAt,
      manufacturingDate: manufacturingDate || null,
      expiryImage: expiryImage || null,
      expiryNotes: expiryNotes || '',
    });

    await autoCheckLowStockGrocery(req.user.id, item);

    res.status(201).json({ success: true, item });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/fridge/bulk
// Seed / replace all items for a user (useful for first-time sync of
// the hardcoded demo items in fridge_screen.dart).
// Body: { items: [ { emoji, label, qty, color, section }, ... ] }
// ─────────────────────────────────────────────────────────────────────────────
router.post('/bulk', async (req, res, next) => {
  try {
    const { items } = req.body;
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ success: false, message: 'items array is required.' });
    }

    // Attach userId to each item and compute default expiresAt if missing
    const docs = items.map((item) => {
      let finalExpiresAt = item.expiresAt || null;
      if (!finalExpiresAt) {
        const days = getDefaultShelfLifeDays(item.label, item.section);
        finalExpiresAt = new Date(Date.now() + days * 24 * 60 * 60 * 1000);
      }
      return {
        ...item,
        userId: req.user.id,
        qty:   item.qty   !== undefined ? Number(item.qty)   : 1,
        color: item.color !== undefined ? Number(item.color) : undefined,
        expiresAt: finalExpiresAt,
      };
    });

    const inserted = await FridgeItem.insertMany(docs, { ordered: false });
    for (const doc of inserted) {
      await autoCheckLowStockGrocery(req.user.id, doc);
    }
    res.status(201).json({ success: true, count: inserted.length, items: inserted });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PUT /api/fridge/:id
// Update any field of a fridge item (commonly qty or expiresAt).
// Body: { qty?, label?, emoji?, color?, section?, expiresAt? }
// ─────────────────────────────────────────────────────────────────────────────
router.put('/:id', async (req, res, next) => {
  try {
    const item = await FridgeItem.findOneAndUpdate(
      { _id: req.params.id, userId: req.user.id },   // ownership check
      { $set: req.body },
      { new: true, runValidators: true }
    );

    if (!item) {
      return res.status(404).json({ success: false, message: 'Item not found.' });
    }

    await autoCheckLowStockGrocery(req.user.id, item);

    res.json({ success: true, item });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/fridge/:id/qty
// Convenience endpoint — increment or decrement qty only.
// Body: { delta: 1 }  or  { delta: -1 }
// ─────────────────────────────────────────────────────────────────────────────
router.patch('/:id/qty', async (req, res, next) => {
  try {
    const delta = Number(req.body.delta);
    if (isNaN(delta)) {
      return res.status(400).json({ success: false, message: 'delta must be a number.' });
    }

    const item = await FridgeItem.findOneAndUpdate(
      { _id: req.params.id, userId: req.user.id },
      { $inc: { qty: delta } },
      { new: true, runValidators: true }
    );

    if (!item) {
      return res.status(404).json({ success: false, message: 'Item not found.' });
    }
    // Prevent negative quantity
    if (item.qty < 0) {
      await FridgeItem.findByIdAndUpdate(item._id, { qty: 0 });
      item.qty = 0;
    }

    await autoCheckLowStockGrocery(req.user.id, item);

    res.json({ success: true, item });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/fridge/expiring
// Returns items expiring within the next 48 hours for the logged-in user.
// ─────────────────────────────────────────────────────────────────────────────
router.get('/expiring', async (req, res, next) => {
  try {
    const now = new Date();
    const next48Hours = new Date(now.getTime() + 48 * 60 * 60 * 1000);

    const items = await FridgeItem.find({
      userId: req.user.id,
      expiresAt: { $gte: now, $lte: next48Hours },
    }).sort({ expiresAt: 1 });

    res.json({ success: true, count: items.length, items });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/fridge/trigger-expiry-check
// Manually triggers the expiry notification email check (useful for testing).
// ─────────────────────────────────────────────────────────────────────────────
const { checkAndSendExpiryNotifications } = require('../utils/expiryScheduler');
router.post('/trigger-expiry-check', async (req, res, next) => {
  try {
    const result = await checkAndSendExpiryNotifications();
    res.json({ success: true, message: 'Expiry check triggered manually.', result });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/fridge/deduct
// Batch-deduct ingredient quantities after cooking a recipe.
// Body: { deductions: [ { itemId, quantityUsed }, ... ] }
// ─────────────────────────────────────────────────────────────────────────────
router.patch('/deduct', async (req, res, next) => {
  try {
    const { deductions, recipeId, recipeTitle } = req.body;
    if (!Array.isArray(deductions) || deductions.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'deductions array is required. Each entry: { itemId, quantityUsed }.',
      });
    }

    const results = [];

    for (const { itemId, label, quantityUsed } of deductions) {
      if ((!itemId && !label) || !quantityUsed || quantityUsed <= 0) continue;

      let item = null;
      if (itemId && mongoose.Types.ObjectId.isValid(itemId)) {
        item = await FridgeItem.findOne({
          _id: itemId,
          userId: req.user.id,
        });
      }

      // Fallback matching by label if itemId is missing, invalid ObjectId, or not found
      if (!item && label) {
        item = await FridgeItem.findOne({
          userId: req.user.id,
          label: { $regex: new RegExp(`^${label.trim()}$`, 'i') },
        });
      }

      if (!item) continue;

      const previousQty = item.qty;
      const actualDeduct = Math.min(quantityUsed, previousQty);
      const newQty = previousQty - actualDeduct;

      if (newQty <= 0) {
        // Remove the item entirely (matches existing delete pattern)
        await FridgeItem.findByIdAndDelete(item._id);
        await autoCheckLowStockGrocery(req.user.id, item, 'Used up while cooking');
        results.push({
          itemId: item._id.toString(),
          label: item.label,
          previousQty,
          newQty: 0,
          removed: true,
          section: item.section || 'pantry',
          quantityUsed: actualDeduct,
        });
      } else {
        item.qty = newQty;
        await item.save();
        await autoCheckLowStockGrocery(req.user.id, item);
        results.push({
          itemId: item._id.toString(),
          label: item.label,
          previousQty,
          newQty,
          removed: false,
          section: item.section || 'pantry',
          quantityUsed: actualDeduct,
        });
      }
    }

    // Log the cooking & deduction event for Analytics Dashboard
    let cookLog = null;
    if (results.length > 0) {
      const detailedDeductions = results.map(r => ({
        itemId: r.itemId,
        label: r.label,
        quantityUsed: r.quantityUsed || 1,
        section: r.section || 'pantry',
        estimatedCost: 1.50,
      }));

      const totalItemsSaved = detailedDeductions.reduce((sum, d) => sum + (Number(d.quantityUsed) || 1), 0);
      const estimatedMoneySaved = Math.round(totalItemsSaved * 1.50 * 100) / 100;

      try {
        cookLog = await CookLog.create({
          userId: req.user.id,
          recipeId: recipeId || null,
          recipeTitle: recipeTitle || 'Cooked Recipe',
          deductions: detailedDeductions,
          totalItemsSaved,
          estimatedMoneySaved,
          cookedAt: new Date(),
        });
      } catch (logErr) {
        console.error('Failed to log cook event:', logErr);
      }
    }

    res.json({
      success: true,
      deductedCount: results.length,
      deducted: results,
      cookLog: cookLog ? {
        id: cookLog._id,
        recipeTitle: cookLog.recipeTitle,
        totalItemsSaved: cookLog.totalItemsSaved,
        estimatedMoneySaved: cookLog.estimatedMoneySaved,
      } : null,
    });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/fridge/:id
// Remove one item (ownership verified).
// ─────────────────────────────────────────────────────────────────────────────
router.delete('/:id', async (req, res, next) => {
  try {
    const item = await FridgeItem.findOneAndDelete({
      _id: req.params.id,
      userId: req.user.id,
    });
    if (!item) {
      return res.status(404).json({ success: false, message: 'Item not found.' });
    }

    await autoCheckLowStockGrocery(req.user.id, item, 'Out of stock in fridge');

    res.json({ success: true, message: 'Item deleted.', deletedId: req.params.id });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/fridge
// Delete ALL items for the current user (clear fridge).
// ─────────────────────────────────────────────────────────────────────────────
router.delete('/', async (req, res, next) => {
  try {
    const result = await FridgeItem.deleteMany({ userId: req.user.id });
    res.json({ success: true, message: `Cleared ${result.deletedCount} items from fridge.` });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/fridge/donations
// Returns all items marked for food donation for the logged-in user.
// ─────────────────────────────────────────────────────────────────────────────
router.get('/donations', async (req, res, next) => {
  try {
    const items = await FridgeItem.find({
      userId: req.user.id,
      $or: [{ isDonation: true }, { donationStatus: 'pledged' }],
    }).sort({ updatedAt: -1 });
    res.json({ success: true, count: items.length, items });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/fridge/:id/donate
// Toggles or updates donation status for a fridge item.
// Body: { isDonation: boolean, donationStatus?: 'none'|'pledged'|'donated', notes?: string }
// ─────────────────────────────────────────────────────────────────────────────
router.patch('/:id/donate', async (req, res, next) => {
  try {
    const { isDonation, donationStatus, notes } = req.body;
    const update = {};

    if (isDonation !== undefined) {
      update.isDonation = Boolean(isDonation);
      if (update.isDonation) {
        update.donationStatus = donationStatus || 'pledged';
      } else {
        update.donationStatus = 'none';
      }
    } else if (donationStatus) {
      update.donationStatus = donationStatus;
      update.isDonation = donationStatus !== 'none';
    }

    if (notes !== undefined) {
      update.donationNotes = String(notes).trim();
    }

    let item = null;
    if (mongoose.Types.ObjectId.isValid(req.params.id)) {
      item = await FridgeItem.findOneAndUpdate(
        { _id: req.params.id, userId: req.user.id },
        { $set: update },
        { new: true }
      );
    }

    if (!item) {
      return res.status(404).json({ success: false, message: 'Item not found.' });
    }

    res.json({
      success: true,
      message: update.isDonation ? 'Item pledged for donation ❤️' : 'Donation flag removed.',
      item,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
