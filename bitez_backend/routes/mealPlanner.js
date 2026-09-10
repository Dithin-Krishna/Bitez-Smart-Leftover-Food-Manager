const router   = require('express').Router();
const MealPlan = require('../models/MealPlan');
const auth     = require('../middleware/authMiddleware');

// All meal planner routes require authentication
router.use(auth);

const VALID_DAYS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/meal-planner
// Returns all pinned meals for the week, grouped by day.
// ─────────────────────────────────────────────────────────────────────────────
router.get('/', async (req, res, next) => {
  try {
    const items = await MealPlan.find({ userId: req.user.id }).sort({ createdAt: 1 });

    const grouped = {
      monday: [],
      tuesday: [],
      wednesday: [],
      thursday: [],
      friday: [],
      saturday: [],
      sunday: [],
    };

    for (const item of items) {
      const day = item.dayOfWeek.toLowerCase();
      if (grouped[day]) {
        grouped[day].push(item);
      }
    }

    res.json({
      success: true,
      totalPinned: items.length,
      mealPlan: grouped,
    });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/meal-planner/pin
// Pin a recipe to a specific day of the week.
// Body: { dayOfWeek, recipeId?, recipeTitle, imageUrl?, ingredients?, cookTime?, mealType?, servings? }
// ─────────────────────────────────────────────────────────────────────────────
router.post('/pin', async (req, res, next) => {
  try {
    const {
      dayOfWeek,
      recipeId,
      recipeTitle,
      imageUrl,
      ingredients,
      cookTime,
      mealType,
      servings,
    } = req.body;

    if (!dayOfWeek || !VALID_DAYS.includes(dayOfWeek.toLowerCase())) {
      return res.status(400).json({
        success: false,
        message: `dayOfWeek must be one of: ${VALID_DAYS.join(', ')}`,
      });
    }

    if (!recipeTitle || recipeTitle.trim().isEmpty) {
      return res.status(400).json({
        success: false,
        message: 'recipeTitle is required.',
      });
    }

    const item = await MealPlan.create({
      userId: req.user.id,
      dayOfWeek: dayOfWeek.toLowerCase(),
      recipeId: recipeId || null,
      recipeTitle: recipeTitle.trim(),
      imageUrl: imageUrl || null,
      ingredients: Array.isArray(ingredients) ? ingredients : [],
      cookTime: Number(cookTime) || 20,
      mealType: (mealType || 'dinner').toLowerCase(),
      servings: Number(servings) || 2,
    });

    res.status(201).json({ success: true, item });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/meal-planner/:id
// Unpin a meal by ID (verifying ownership).
// ─────────────────────────────────────────────────────────────────────────────
router.delete('/:id', async (req, res, next) => {
  try {
    const item = await MealPlan.findOneAndDelete({
      _id: req.params.id,
      userId: req.user.id,
    });

    if (!item) {
      return res.status(404).json({ success: false, message: 'Meal not found.' });
    }

    res.json({ success: true, message: 'Recipe unpinned from meal planner.' });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/meal-planner/consolidated-ingredients
// Collects all ingredients across all pinned meals for the week.
// ─────────────────────────────────────────────────────────────────────────────
router.get('/consolidated-ingredients', async (req, res, next) => {
  try {
    const items = await MealPlan.find({ userId: req.user.id });

    const ingredientSet = new Set();
    const list = [];

    for (const item of items) {
      if (Array.isArray(item.ingredients)) {
        for (const raw of item.ingredients) {
          const clean = raw.trim();
          if (clean && !ingredientSet.has(clean.toLowerCase())) {
            ingredientSet.add(clean.toLowerCase());
            list.push(clean);
          }
        }
      }
    }

    res.json({
      success: true,
      count: list.length,
      ingredients: list,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
