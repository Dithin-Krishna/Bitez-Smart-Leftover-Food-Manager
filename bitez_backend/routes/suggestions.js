const router     = require('express').Router();
const jwt        = require('jsonwebtoken');
const Suggestion = require('../models/Suggestion');
const User       = require('../models/User');
const auth       = require('../middleware/authMiddleware');
const { requireAdmin } = require('../middleware/authMiddleware');

/**
 * Optional authentication helper:
 * Attaches req.user if valid token provided, including admin detection.
 */
const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.split(' ')[1];
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const user = await User.findById(decoded.id).select('_id name email role');
      if (user) {
        const adminEmails = [
          (process.env.ADMIN_ALERT_EMAIL || '').toLowerCase().trim(),
          (process.env.EMAIL_USER || '').toLowerCase().trim(),
          'admin@bitez.app',
        ].filter(Boolean);

        const isEmailAdmin = user.email && adminEmails.includes(user.email.toLowerCase().trim());
        const isAdmin = user.role === 'admin' || isEmailAdmin;

        req.user = {
          id: user._id.toString(),
          name: user.name,
          email: user.email,
          role: isAdmin ? 'admin' : (user.role || 'user'),
          isAdmin,
        };
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
      message: 'Thank you for your suggestion! Visible to you and Bitez admins.',
      data: suggestion,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * @route   GET /api/suggestions/my
 * @desc    Get suggestions submitted by logged-in user, or ALL suggestions if admin
 * @access  Private (strictly user + admin)
 */
router.get('/my', auth, async (req, res, next) => {
  try {
    // Security check:
    // Admin sees all suggestions across all users
    // Regular users see ONLY their own submitted suggestions
    const query = req.user.isAdmin ? {} : { userId: req.user.id };

    const suggestions = await Suggestion.find(query)
      .sort({ createdAt: -1 })
      .limit(req.user.isAdmin ? 100 : 50);

    res.json({
      success: true,
      isAdmin: req.user.isAdmin,
      data: suggestions,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * @route   GET /api/suggestions
 * @desc    Fetch suggestions (Filtered by role: admin gets all, user gets own only)
 * @access  Private
 */
router.get('/', auth, async (req, res, next) => {
  try {
    const query = req.user.isAdmin ? {} : { userId: req.user.id };
    const suggestions = await Suggestion.find(query)
      .sort({ createdAt: -1 })
      .limit(req.user.isAdmin ? 100 : 50);

    res.json({
      success: true,
      isAdmin: req.user.isAdmin,
      data: suggestions,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * @route   GET /api/suggestions/public
 * @desc    Restricted endpoint: suggestions are confidential to user & admin
 * @access  Admin Only
 */
router.get('/public', auth, async (req, res, next) => {
  try {
    if (!req.user.isAdmin) {
      return res.status(403).json({
        success: false,
        message: 'Access restricted: suggestions are private to the author and admins.',
      });
    }

    const suggestions = await Suggestion.find()
      .sort({ createdAt: -1 })
      .limit(50);

    res.json({
      success: true,
      data: suggestions,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * @route   PATCH /api/suggestions/:id/status
 * @desc    Update status of a suggestion
 * @access  Admin Only
 */
router.patch('/:id/status', auth, requireAdmin, async (req, res, next) => {
  try {
    const { status } = req.body;
    const allowed = ['under_review', 'planned', 'implemented', 'closed'];
    if (!status || !allowed.includes(status)) {
      return res.status(400).json({
        success: false,
        message: `Invalid status. Allowed values: ${allowed.join(', ')}`,
      });
    }

    const suggestion = await Suggestion.findByIdAndUpdate(
      req.params.id,
      { status },
      { new: true }
    );

    if (!suggestion) {
      return res.status(404).json({ success: false, message: 'Suggestion not found' });
    }

    res.json({
      success: true,
      message: `Status updated to ${status}`,
      data: suggestion,
    });
  } catch (err) {
    next(err);
  }
});

/**
 * @route   DELETE /api/suggestions/:id
 * @desc    Delete a suggestion
 * @access  Private (Author or Admin)
 */
router.delete('/:id', auth, async (req, res, next) => {
  try {
    const suggestion = await Suggestion.findById(req.params.id);
    if (!suggestion) {
      return res.status(404).json({ success: false, message: 'Suggestion not found' });
    }

    if (!req.user.isAdmin && suggestion.userId?.toString() !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Forbidden: You can only delete your own suggestions.',
      });
    }

    await suggestion.deleteOne();
    res.json({ success: true, message: 'Suggestion deleted successfully' });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
