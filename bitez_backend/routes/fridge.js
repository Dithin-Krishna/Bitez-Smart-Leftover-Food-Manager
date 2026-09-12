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

/**
 * Normalizes a food label for consistent comparison and deduplication:
 * - Trims whitespace and converts to lower-case
 * - Removes non-alphanumeric characters (punctuation, hyphens, etc.)
 * - Handles English pluralizations (e.g. carrots -> carrot, tomatoes -> tomato, berries -> berry, loaves -> loaf, eggs -> egg)
 */
function normalizeLabel(label) {
  if (!label || typeof label !== 'string') return '';
  let clean = label.trim().toLowerCase().replace(/[^\w\s]/g, '');

  if (clean.endsWith('oes')) {
    clean = clean.slice(0, -2);
  } else if (clean.endsWith('ies')) {
    clean = clean.slice(0, -3) + 'y';
  } else if (clean.endsWith('ves')) {
    clean = clean.slice(0, -3) + 'f';
  } else if (clean.endsWith('s') && !clean.endsWith('ss')) {
    clean = clean.slice(0, -1);
  }
  return clean;
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/fridge
// Returns all fridge items for the logged-in user, grouped by section.
// Query param: ?section=frozen  (optional — filter by section)
// Automatically deduplicates and merges existing duplicate items (e.g. carrot - 19, carrot - 4)
// ─────────────────────────────────────────────────────────────────────────────
router.get('/', async (req, res, next) => {
  try {
    const filter = { userId: req.user.id };
    if (req.query.section) filter.section = req.query.section;

    const items = await FridgeItem.find(filter).sort({ section: 1, createdAt: 1 });

    // Deduplicate and merge any duplicate records for this user
    const uniqueMap = new Map();
    const redundantIds = [];
    const itemsToUpdate = [];

    for (const item of items) {
      const norm = normalizeLabel(item.label);
      const key = `${item.section}:${norm}`;

      if (!uniqueMap.has(key)) {
        uniqueMap.set(key, item);
      } else {
        const primary = uniqueMap.get(key);
        // Merge quantities
        primary.qty = (primary.qty || 0) + (item.qty || 0);

        // Prefer Title Case or capitalized label over all-lowercase
        if (primary.label === primary.label.toLowerCase() && item.label !== item.label.toLowerCase()) {
          primary.label = item.label;
        }
        // Prefer non-generic emoji
        if ((!primary.emoji || primary.emoji === '🛒') && item.emoji && item.emoji !== '🛒') {
          primary.emoji = item.emoji;
        }
        // Keep the latest expiry date
        if (item.expiresAt) {
          if (!primary.expiresAt || new Date(item.expiresAt) > new Date(primary.expiresAt)) {
            primary.expiresAt = item.expiresAt;
          }
        }
        // Preserve any manufacturing dates or images if primary lacks them
        if (!primary.manufacturingDate && item.manufacturingDate) {
          primary.manufacturingDate = item.manufacturingDate;
        }
        if (!primary.expiryImage && item.expiryImage) {
          primary.expiryImage = item.expiryImage;
        }
        if (!primary.expiryNotes && item.expiryNotes) {
          primary.expiryNotes = item.expiryNotes;
        }

        redundantIds.push(item._id);
        if (!itemsToUpdate.some(it => it._id.toString() === primary._id.toString())) {
          itemsToUpdate.push(primary);
        }
      }
    }

    // Clean up duplicate items from MongoDB Atlas
    if (redundantIds.length > 0) {
      await FridgeItem.deleteMany({ _id: { $in: redundantIds } });
      for (const primary of itemsToUpdate) {
        await FridgeItem.updateOne(
          { _id: primary._id },
          {
            $set: {
              qty: primary.qty,
              label: primary.label,
              emoji: primary.emoji,
              expiresAt: primary.expiresAt,
              manufacturingDate: primary.manufacturingDate,
              expiryImage: primary.expiryImage,
              expiryNotes: primary.expiryNotes,
            }
          }
        );
      }
    }

    const finalItems = Array.from(uniqueMap.values());

    // Also return grouped structure for convenience
    const grouped = {};
    for (const item of finalItems) {
      if (!grouped[item.section]) grouped[item.section] = [];
      grouped[item.section].push(item);
    }

    res.json({ success: true, count: finalItems.length, items: finalItems, grouped });
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
// Add a single new item (merges quantity if item already exists in section).
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

    const norm = normalizeLabel(label);
    const addedQty = qty !== undefined ? Number(qty) : 1;

    // Check if an item already exists in this section with matching normalized label
    const existingItems = await FridgeItem.find({ userId: req.user.id, section });
    const existing = existingItems.find(it => normalizeLabel(it.label) === norm);

    if (existing) {
      existing.qty = (existing.qty || 0) + addedQty;
      if (emoji && emoji !== '🛒') existing.emoji = emoji;
      if (expiresAt) existing.expiresAt = expiresAt;
      if (manufacturingDate) existing.manufacturingDate = manufacturingDate;
      if (expiryImage) existing.expiryImage = expiryImage;
      if (expiryNotes) existing.expiryNotes = expiryNotes;
      await existing.save();

      await autoCheckLowStockGrocery(req.user.id, existing);
      return res.status(200).json({ success: true, item: existing, merged: true });
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
      qty: addedQty,
      color: color !== undefined ? Number(color) : undefined,
      section,
      expiresAt: finalExpiresAt,
      manufacturingDate: manufacturingDate || null,
      expiryImage: expiryImage || null,
      expiryNotes: expiryNotes || '',
    });

    await autoCheckLowStockGrocery(req.user.id, item);

    res.status(201).json({ success: true, item, merged: false });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/fridge/bulk
// Bulk add items (e.g. from camera vision or seed).
// Merges quantities if item with same normalized label already exists.
// Body: { items: [ { emoji, label, qty, color, section }, ... ] }
// ─────────────────────────────────────────────────────────────────────────────
router.post('/bulk', async (req, res, next) => {
  try {
    const { items } = req.body;
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ success: false, message: 'items array is required.' });
    }

    // Retrieve all existing items for this user to check for duplicates & merge
    const existingItems = await FridgeItem.find({ userId: req.user.id });
    const existingMap = new Map();
    for (const it of existingItems) {
      const key = `${it.section}:${normalizeLabel(it.label)}`;
      existingMap.set(key, it);
    }

    const finalResults = [];
    for (const rawItem of items) {
      if (!rawItem.label || !rawItem.section) continue;

      const norm = normalizeLabel(rawItem.label);
      const key = `${rawItem.section}:${norm}`;
      const addQty = rawItem.qty !== undefined ? Number(rawItem.qty) : 1;

      if (existingMap.has(key)) {
        // Merge into existing item
        const existing = existingMap.get(key);
        existing.qty = (existing.qty || 0) + addQty;
        if (rawItem.emoji && rawItem.emoji !== '🛒') existing.emoji = rawItem.emoji;
        if (rawItem.expiresAt) existing.expiresAt = rawItem.expiresAt;
        if (rawItem.manufacturingDate) existing.manufacturingDate = rawItem.manufacturingDate;
        if (rawItem.expiryImage) existing.expiryImage = rawItem.expiryImage;
        if (rawItem.expiryNotes) existing.expiryNotes = rawItem.expiryNotes;
        await existing.save();
        await autoCheckLowStockGrocery(req.user.id, existing);
        finalResults.push(existing);
      } else {
        let finalExpiresAt = rawItem.expiresAt || null;
        if (!finalExpiresAt) {
          const days = getDefaultShelfLifeDays(rawItem.label, rawItem.section);
          finalExpiresAt = new Date(Date.now() + days * 24 * 60 * 60 * 1000);
        }

        const created = await FridgeItem.create({
          userId: req.user.id,
          emoji: rawItem.emoji || '🛒',
          label: rawItem.label.trim(),
          qty: addQty,
          color: rawItem.color !== undefined ? Number(rawItem.color) : undefined,
          section: rawItem.section,
          expiresAt: finalExpiresAt,
          manufacturingDate: rawItem.manufacturingDate || null,
          expiryImage: rawItem.expiryImage || null,
          expiryNotes: rawItem.expiryNotes || '',
        });

        // Track in existingMap so any subsequent items in the same bulk array merge too
        existingMap.set(key, created);
        await autoCheckLowStockGrocery(req.user.id, created);
        finalResults.push(created);
      }
    }

    res.status(201).json({ success: true, count: finalResults.length, items: finalResults });
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
        const cleanLabel = label.trim();
        const escaped = cleanLabel.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        item = await FridgeItem.findOne({
          userId: req.user.id,
          label: { $regex: new RegExp(`^${escaped}$`, 'i') },
        });

        // If not found, match by normalizeLabel or substring
        if (!item) {
          const userItems = await FridgeItem.find({ userId: req.user.id });
          const targetNorm = normalizeLabel(cleanLabel);
          item = userItems.find(ui => normalizeLabel(ui.label) === targetNorm);

          if (!item) {
            const lowerLabel = cleanLabel.toLowerCase();
            for (const ui of userItems) {
              const uiLabel = (ui.label || '').trim().toLowerCase();
              if (uiLabel && (uiLabel.includes(lowerLabel) || lowerLabel.includes(uiLabel))) {
                item = ui;
                break;
              }
            }
          }
        }
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
