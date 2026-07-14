const router     = require('express').Router();
const FridgeItem = require('../models/FridgeItem');
const auth       = require('../middleware/authMiddleware');

// All fridge routes require authentication
router.use(auth);

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
// POST /api/fridge
// Add a single new item.
// Body: { emoji, label, qty, color, section, expiresAt? }
// ─────────────────────────────────────────────────────────────────────────────
router.post('/', async (req, res, next) => {
  try {
    const { emoji, label, qty, color, section, expiresAt } = req.body;

    if (!emoji || !label || !section) {
      return res.status(400).json({
        success: false,
        message: 'emoji, label, and section are required.',
      });
    }

    const item = await FridgeItem.create({
      userId: req.user.id,
      emoji,
      label: label.trim(),
      qty:   qty   !== undefined ? Number(qty) : 1,
      color: color !== undefined ? Number(color) : undefined,
      section,
      expiresAt: expiresAt || null,
    });

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

    // Attach userId to each item
    const docs = items.map((item) => ({
      ...item,
      userId: req.user.id,
      qty:   item.qty   !== undefined ? Number(item.qty)   : 1,
      color: item.color !== undefined ? Number(item.color) : undefined,
    }));

    const inserted = await FridgeItem.insertMany(docs, { ordered: false });
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

    res.json({ success: true, item });
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

module.exports = router;
