const router = require('express').Router();
const Recipe = require('../models/Recipe');
const auth   = require('../middleware/authMiddleware');
const { recipeLimiter } = require('../middleware/rateLimiters');

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

// ─────────────────────────────────────────────────────────────────────────────
// PROXY ENDPOINTS (Rate-limited to protect external API quotas)
// ─────────────────────────────────────────────────────────────────────────────

// GET /api/recipes/proxy/spoonacular/search
router.get('/proxy/spoonacular/search', recipeLimiter, async (req, res, next) => {
  try {
    const apiKey = process.env.SPOONACULAR_API_KEY;
    if (!apiKey) {
      return res.status(503).json({
        success: false,
        message: 'Spoonacular API key is not configured on the server.',
      });
    }

    const { query, includeIngredients, cuisine, number = 10 } = req.query;
    const url = new URL('https://api.spoonacular.com/recipes/complexSearch');
    if (query) url.searchParams.set('query', query);
    if (includeIngredients) url.searchParams.set('includeIngredients', includeIngredients);
    if (cuisine) url.searchParams.set('cuisine', cuisine);
    url.searchParams.set('sort', 'min-missing-ingredients');
    url.searchParams.set('fillIngredients', 'true');
    url.searchParams.set('addRecipeInformation', 'true');
    url.searchParams.set('ignorePantry', 'true');
    url.searchParams.set('number', String(Math.min(Number(number) || 10, 25)));
    url.searchParams.set('apiKey', apiKey);

    const apiRes = await fetch(url.toString());
    const data = await apiRes.json();
    return res.status(apiRes.status).json(data);
  } catch (err) {
    next(err);
  }
});

// GET /api/recipes/proxy/spoonacular/:id
router.get('/proxy/spoonacular/:id', recipeLimiter, async (req, res, next) => {
  try {
    const apiKey = process.env.SPOONACULAR_API_KEY;
    if (!apiKey) {
      return res.status(503).json({
        success: false,
        message: 'Spoonacular API key is not configured on the server.',
      });
    }

    const { id } = req.params;
    const url = `https://api.spoonacular.com/recipes/${id}/information?includeInstructions=true&apiKey=${apiKey}`;
    const apiRes = await fetch(url);
    const data = await apiRes.json();
    return res.status(apiRes.status).json(data);
  } catch (err) {
    next(err);
  }
});

// GET /api/recipes/proxy/mealdb/filter
router.get('/proxy/mealdb/filter', recipeLimiter, async (req, res, next) => {
  try {
    const { i } = req.query;
    if (!i) {
      return res.status(400).json({ success: false, message: 'Ingredient query param i is required.' });
    }
    const url = `https://www.themealdb.com/api/json/v1/1/filter.php?i=${encodeURIComponent(i)}`;
    const apiRes = await fetch(url);
    const data = await apiRes.json();
    return res.status(apiRes.status).json(data);
  } catch (err) {
    next(err);
  }
});

// GET /api/recipes/proxy/mealdb/lookup
router.get('/proxy/mealdb/lookup', recipeLimiter, async (req, res, next) => {
  try {
    const { i } = req.query;
    if (!i) {
      return res.status(400).json({ success: false, message: 'Meal id param i is required.' });
    }
    const url = `https://www.themealdb.com/api/json/v1/1/lookup.php?i=${encodeURIComponent(i)}`;
    const apiRes = await fetch(url);
    const data = await apiRes.json();
    return res.status(apiRes.status).json(data);
  } catch (err) {
    next(err);
  }
});

module.exports = router;

