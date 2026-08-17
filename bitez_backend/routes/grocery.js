const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const GroceryItem = require('../models/GroceryItem');
const FridgeItem = require('../models/FridgeItem');
const { validateAndEnrich } = require('../models/FoodCatalog');

router.use(authMiddleware);

/**
 * GET /api/grocery
 * Returns all grocery items for the logged in user.
 */
router.get('/', async (req, res, next) => {
  try {
    const items = await GroceryItem.find({ userId: req.user.id }).sort({ isBought: 1, createdAt: -1 });
    res.json({
      success: true,
      count: items.length,
      items,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/grocery
 * Add a custom item to the grocery list.
 * Body: { label, emoji?, qty?, category?, section? }
 */
router.post('/', async (req, res, next) => {
  try {
    const { label, emoji, qty, category, section } = req.body;
    if (!label) {
      return res.status(400).json({ success: false, message: 'Label is required' });
    }

    const enriched = validateAndEnrich(label);

    const item = await GroceryItem.create({
      userId: req.user.id,
      label: label.trim(),
      emoji: emoji || (enriched ? enriched.emoji : '🛒'),
      qty: qty !== undefined ? Number(qty) : 1,
      category: category || (enriched ? enriched.category : 'Produce'),
      section: section || (enriched ? enriched.defaultSection : 'veggies'),
      isBought: false,
      isAiSuggested: false,
    });

    res.status(201).json({ success: true, item });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/grocery/generate
 * Analyzes items in the user's Virtual Fridge and calls Gemini AI to generate smart restock suggestions.
 */
router.post('/generate', async (req, res, next) => {
  try {
    // Fetch current virtual fridge items
    const fridgeItems = await FridgeItem.find({ userId: req.user.id });
    const fridgeNames = fridgeItems.map(i => `${i.label} (qty: ${i.qty})`).join(', ');

    // 1. Direct Low-Stock / Out-of-Stock Fridge Check (qty <= 1)
    const lowStockSuggestions = fridgeItems
      .filter(i => i.qty <= 1)
      .map(i => ({
        label: i.label,
        emoji: i.emoji || '🛒',
        category: 'Produce',
        section: i.section || 'veggies',
        qty: 1,
        reason: i.qty === 0 ? 'Out of stock in fridge' : `Low stock in fridge (qty: ${i.qty})`,
      }));

    const geminiKey = process.env.GEMINI_API_KEY;
    let suggestions = [...lowStockSuggestions];

    if (geminiKey) {
      const candidateModels = [
        'gemini-flash-lite-latest',
        'gemini-flash-latest',
        'gemini-3.1-flash-lite',
        'gemini-3-flash-preview',
        'gemini-2.0-flash-lite',
        'gemini-2.0-flash'
      ];

      const promptText = `User's current Virtual Fridge contents: [${fridgeNames || 'Empty Fridge'}].
Analyze the fridge items and generate 4 to 6 smart grocery restock suggestions. Include missing essential kitchen staples (e.g. Eggs, Milk, Bread, Onion, Salt, Butter) or items with low quantity.
Return ONLY a raw JSON array of objects with schema:
[
  { "label": "Egg", "emoji": "🥚", "category": "Dairy & Eggs", "section": "dairy", "qty": 1, "reason": "Essential kitchen staple" },
  ...
]
Do not output markdown backticks or extra text.`;

      for (const modelName of candidateModels) {
        try {
          const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${geminiKey}`;
          const response = await fetch(geminiUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              contents: [{ parts: [{ text: promptText }] }]
            }),
          });

          if (response.ok) {
            const data = await response.json();
            const text = data.candidates?.[0]?.content?.parts?.[0]?.text?.trim();
            if (text) {
              const match = text.match(/\[\s*[\s\S]*?\s*\]/);
              if (match) {
                try {
                  const parsed = JSON.parse(match[0]);
                  if (Array.isArray(parsed) && parsed.length > 0) {
                    suggestions = [...suggestions, ...parsed];
                  }
                } catch (_) {}
              }
            }
            if (suggestions.length > lowStockSuggestions.length) break;
          }
        } catch (err) {
          console.error(`Grocery AI generation error (${modelName}):`, err.message);
        }
      }
    }

    // Default intelligent fallbacks if AI fails or key is missing
    if (suggestions.length === 0) {
      suggestions = [
        { label: 'Egg', emoji: '🥚', category: 'Dairy & Eggs', section: 'dairy', qty: 1, reason: 'Restock essential protein' },
        { label: 'Milk', emoji: '🥛', category: 'Dairy & Eggs', section: 'dairy', qty: 1, reason: 'Daily kitchen staple' },
        { label: 'Bread', emoji: '🍞', category: 'Staples & Pantry', section: 'condiments', qty: 1, reason: 'Breakfast staple' },
        { label: 'Onion', emoji: '🧅', category: 'Produce', section: 'veggies', qty: 1, reason: 'Cooking base ingredient' },
        { label: 'Tomato', emoji: '🍅', category: 'Produce', section: 'veggies', qty: 1, reason: 'Fresh vegetable restock' },
      ];
    }

    // Insert new AI suggestions into GroceryItem collection (avoiding duplicates)
    const existingList = await GroceryItem.find({ userId: req.user.id });
    const existingLabels = new Set(existingList.map(i => i.label.toLowerCase()));

    const newDocs = [];
    for (const sug of suggestions) {
      if (sug.label && !existingLabels.has(sug.label.toLowerCase())) {
        const enriched = validateAndEnrich(sug.label);
        newDocs.push({
          userId: req.user.id,
          label: sug.label.trim(),
          emoji: sug.emoji || (enriched ? enriched.emoji : '🛒'),
          qty: sug.qty || 1,
          category: sug.category || (enriched ? enriched.category : 'Produce'),
          section: sug.section || (enriched ? enriched.defaultSection : 'veggies'),
          isBought: false,
          isAiSuggested: true,
          reason: sug.reason || 'AI Smart Restock',
        });
      }
    }

    if (newDocs.length > 0) {
      await GroceryItem.insertMany(newDocs);
    }

    const updatedList = await GroceryItem.find({ userId: req.user.id }).sort({ isBought: 1, createdAt: -1 });
    res.json({
      success: true,
      addedCount: newDocs.length,
      items: updatedList,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * PUT /api/grocery/:id
 * Update grocery item status or quantity.
 */
router.put('/:id', async (req, res, next) => {
  try {
    const item = await GroceryItem.findOneAndUpdate(
      { _id: req.params.id, userId: req.user.id },
      { $set: req.body },
      { new: true, runValidators: true }
    );
    if (!item) {
      return res.status(404).json({ success: false, message: 'Grocery item not found' });
    }
    res.json({ success: true, item });
  } catch (err) {
    next(err);
  }
});

/**
 * DELETE /api/grocery/:id
 * Delete a grocery item.
 */
router.delete('/:id', async (req, res, next) => {
  try {
    const item = await GroceryItem.findOneAndDelete({
      _id: req.params.id,
      userId: req.user.id,
    });
    if (!item) {
      return res.status(404).json({ success: false, message: 'Grocery item not found' });
    }
    res.json({ success: true, message: 'Item removed from grocery list' });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/grocery/move-to-fridge
 * Transfers all checked-off (bought) grocery items into the user's Virtual Fridge inventory.
 */
router.post('/move-to-fridge', async (req, res, next) => {
  try {
    const boughtItems = await GroceryItem.find({ userId: req.user.id, isBought: true });
    if (boughtItems.length === 0) {
      return res.status(400).json({ success: false, message: 'No bought items found to move to fridge.' });
    }

    const fridgeDocs = boughtItems.map(item => ({
      userId: req.user.id,
      label: item.label,
      emoji: item.emoji,
      qty: item.qty,
      color: 0xFF2A4E7C,
      section: item.section || 'veggies',
    }));

    await FridgeItem.insertMany(fridgeDocs);
    await GroceryItem.deleteMany({ userId: req.user.id, isBought: true });

    res.json({
      success: true,
      movedCount: boughtItems.length,
      message: `Transferred ${boughtItems.length} items to Virtual Fridge.`,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
