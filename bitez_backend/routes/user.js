const router = require('express').Router();
const bcrypt = require('bcryptjs');
const User   = require('../models/User');
const auth   = require('../middleware/authMiddleware');

// All user routes require authentication
router.use(auth);

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/user/me
// Return the current user's profile.
// ─────────────────────────────────────────────────────────────────────────────
router.get('/me', async (req, res, next) => {
  try {
    const user = await User.findById(req.user.id);
    if (!user) return res.status(404).json({ success: false, message: 'User not found.' });

    res.json({
      success: true,
      user: {
        id:        user._id,
        name:      user.name,
        email:     user.email,
        age:       user.age,
        gender:    user.gender,
        phone:     user.phone,
        avatarUrl: user.avatarUrl,
        createdAt: user.createdAt,
      },
    });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PUT /api/user/me
// Update profile fields (name, age, gender, phone, avatarUrl).
// Does NOT update email or password here (separate endpoints for those).
// ─────────────────────────────────────────────────────────────────────────────
router.put('/me', async (req, res, next) => {
  try {
    const allowed  = ['name', 'age', 'gender', 'phone', 'avatarUrl'];
    const updates  = {};
    for (const key of allowed) {
      if (req.body[key] !== undefined) updates[key] = req.body[key];
    }

    const user = await User.findByIdAndUpdate(
      req.user.id,
      { $set: updates },
      { new: true, runValidators: true }
    );
    if (!user) return res.status(404).json({ success: false, message: 'User not found.' });

    res.json({
      success: true,
      message: 'Profile updated.',
      user: { id: user._id, name: user.name, email: user.email, age: user.age, gender: user.gender, phone: user.phone, avatarUrl: user.avatarUrl },
    });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// PUT /api/user/change-password
// Body: { currentPassword, newPassword }
// ─────────────────────────────────────────────────────────────────────────────
router.put('/change-password', async (req, res, next) => {
  try {
    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ success: false, message: 'Both currentPassword and newPassword are required.' });
    }
    if (newPassword.length < 6) {
      return res.status(400).json({ success: false, message: 'New password must be at least 6 characters.' });
    }

    const user = await User.findById(req.user.id).select('+passwordHash');
    if (!user) return res.status(404).json({ success: false, message: 'User not found.' });

    const isMatch = await user.comparePassword(currentPassword);
    if (!isMatch) {
      return res.status(401).json({ success: false, message: 'Current password is incorrect.' });
    }

    user.passwordHash = newPassword;   // pre-save hook will hash it
    await user.save();

    res.json({ success: true, message: 'Password changed successfully.' });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/user/me
// Permanently delete the account and all associated data.
// ─────────────────────────────────────────────────────────────────────────────
router.delete('/me', async (req, res, next) => {
  try {
    const FridgeItem = require('../models/FridgeItem');
    const Recipe     = require('../models/Recipe');

    // Delete all user data first
    await Promise.all([
      FridgeItem.deleteMany({ userId: req.user.id }),
      Recipe.deleteMany({ userId: req.user.id }),
      User.findByIdAndDelete(req.user.id),
    ]);

    res.json({ success: true, message: 'Account and all data permanently deleted.' });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
