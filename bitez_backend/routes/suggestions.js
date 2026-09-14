const router     = require('express').Router();
const jwt        = require('jsonwebtoken');
const Suggestion = require('../models/Suggestion');
const User       = require('../models/User');
const auth       = require('../middleware/authMiddleware');

/**
 * Optional authentication helper:
 * Attaches req.user if valid token provided, but doesn't block unauthenticated requests.
 */
const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.split(' ')[1];
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const user = await User.findById(decoded.id).select('_id name email');
      if (user) {
        req.user = { id: user._id.toString(), name: user.name, email: user.email };
      }
    }
  } catch (_) {
    // Ignore invalid tokens for optional auth
  }
  next();
};

/**
 * @route   POST /api/suggestions
 * @desc    Submit an app suggestion or feedback
 * @access  Public / Authenticated
 */
router.post('/', optionalAuth, async (req, res, next) => {
  try {
    const { title, description, category, rating, isAnonymous } = req.body;

    if (!title || !title.trim()) {
      return res.status(400).json({ success: false, message: 'Suggestion title is required' });
    }
    if (!description || !description.trim()) {
      return res.status(400).json({ success: false, message: 'Suggestion description is required' });
    }

    let userId = null;
    let userName = 'Anonymous User';
    let userEmail = '';

    if (req.user && !isAnonymous) {
      userId = req.user.id;
      userName = req.user.name;
      userEmail = req.user.email;
    } else if (req.body.userName && !isAnonymous) {
      userName = req.body.userName.trim();
      userEmail = req.body.userEmail ? req.body.userEmail.trim() : '';
    }

    const suggestion = await Suggestion.create({
      userId,
      userName,
      userEmail,
      category: ['feature', 'ui_ux', 'recipe_idea', 'bug_report', 'general'].includes(category)
        ? category
        : 'feature',
      title: title.trim(),
      description: description.trim(),
      rating: Number.isInteger(rating) && rating >= 1 && rating <= 5 ? rating : 5,
      status: 'under_review',
    });

    res.status(201).json({
      success: true,
      message: 'Thank you for your suggestion! Our team will review it.',
      data: suggestion,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * @route   GET /api/suggestions/my
 * @desc    Get suggestions submitted by logged-in user
 * @access  Private
 */
router.get('/my', auth, async (req, res, next) => {
  try {
    const suggestions = await Suggestion.find({ userId: req.user.id })
      .sort({ createdAt: -1 })
      .limit(30);

    res.json({
      success: true,
      data: suggestions,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * @route   GET /api/suggestions/public
 * @desc    Get curated community suggestions & status
 * @access  Public
 */
router.get('/public', async (req, res, next) => {
  try {
    const suggestions = await Suggestion.find()
      .select('title category rating status createdAt')
      .sort({ createdAt: -1 })
      .limit(20);

    res.json({
      success: true,
      data: suggestions,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
