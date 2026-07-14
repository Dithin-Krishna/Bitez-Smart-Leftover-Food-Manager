const router = require('express').Router();
const Recipe = require('../models/Recipe');
const auth   = require('../middleware/authMiddleware');

// All recipe routes require authentication
router.use(auth);

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/recipes
// Fetch all recipes for the logged-in user.
// Query params:
//   ?saved=true   — only saved recipes
//   ?limit=10     — pagination limit (default 20)
//   ?skip=0       — pagination offset
// ─────────────────────────────────────────────────────────────────────────────
router.get('/', async (req, res, next) => {
  try {
    const filter = { userId: req.user.id };
    if (req.query.saved === 'true') filter.isSaved = true;

    const limit = Math.min(Number(req.query.limit) || 20, 100);
    const skip  = Number(req.query.skip) || 0;

    const [recipes, total] = await Promise.all([
      Recipe.find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .select('-aiRaw'),
      Recipe.countDocuments(filter),
    ]);

    res.json({ success: true, total, count: recipes.length, recipes });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/recipes/:id
// Fetch a single recipe by ID.
// ─────────────────────────────────────────────────────────────────────────────
router.get('/:id', async (req, res, next) => {
  try {
    const recipe = await Recipe.findOne({ _id: req.params.id, userId: req.user.id });
    if (!recipe) {
      return res.status(404).json({ success: false, message: 'Recipe not found.' });
    }
    res.json({ success: true, recipe });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/recipes
// Save a new AI-generated recipe.
// Body: { title, description?, ingredients, steps, fridgeItemsUsed?,
//         imageUrl?, inputPhotoUrl?, cookTime?, servings?, difficulty?, aiRaw? }
// ─────────────────────────────────────────────────────────────────────────────
router.post('/', async (req, res, next) => {
  try {
    const {
      title, description, ingredients, steps,
      fridgeItemsUsed, imageUrl, inputPhotoUrl,
      cookTime, servings, difficulty, aiRaw,
    } = req.body;

    if (!title) {
      return res.status(400).json({ success: false, message: 'Recipe title is required.' });
    }

    const recipe = await Recipe.create({
      userId: req.user.id,
      title:          title.trim(),
      description:    description  || '',
      ingredients:    Array.isArray(ingredients)    ? ingredients    : [],
      steps:          Array.isArray(steps)          ? steps          : [],
      fridgeItemsUsed: Array.isArray(fridgeItemsUsed) ? fridgeItemsUsed : [],
      imageUrl:       imageUrl       || null,
      inputPhotoUrl:  inputPhotoUrl  || null,
      cookTime:       cookTime  ? Number(cookTime)  : null,
      servings:       servings  ? Number(servings)  : 2,
      difficulty:     difficulty || 'Easy',
      isSaved:        false,
      aiRaw:          aiRaw || undefined,
    });

    res.status(201).json({ success: true, recipe });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/recipes/:id/save
// Toggle the isSaved flag (bookmark / unbookmark a recipe).
// ─────────────────────────────────────────────────────────────────────────────
router.patch('/:id/save', async (req, res, next) => {
  try {
    const recipe = await Recipe.findOne({ _id: req.params.id, userId: req.user.id });
    if (!recipe) {
      return res.status(404).json({ success: false, message: 'Recipe not found.' });
    }
    recipe.isSaved = !recipe.isSaved;
    await recipe.save();
    res.json({
      success: true,
      isSaved: recipe.isSaved,
      message: recipe.isSaved ? 'Recipe saved.' : 'Recipe unsaved.',
    });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/recipes/:id
// Delete a recipe (only owner can delete).
// ─────────────────────────────────────────────────────────────────────────────
router.delete('/:id', async (req, res, next) => {
  try {
    const recipe = await Recipe.findOneAndDelete({ _id: req.params.id, userId: req.user.id });
    if (!recipe) {
      return res.status(404).json({ success: false, message: 'Recipe not found.' });
    }
    res.json({ success: true, message: 'Recipe deleted.', deletedId: req.params.id });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
