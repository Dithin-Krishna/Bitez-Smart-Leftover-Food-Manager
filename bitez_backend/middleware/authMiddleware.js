const jwt  = require('jsonwebtoken');
const User = require('../models/User');

/**
 * authMiddleware — protects routes that require a logged-in user.
 *
 * Expects header:  Authorization: Bearer <JWT_TOKEN>
 *
 * On success: attaches req.user = { id, name, email } and calls next().
 * On failure: responds with 401 Unauthorized.
 */
const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'Access denied. No token provided.',
      });
    }

    const token = authHeader.split(' ')[1];

    // Verify signature and expiry
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Confirm user still exists in DB
    const user = await User.findById(decoded.id).select('_id name email');
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Token is valid but the user no longer exists.',
      });
    }

    req.user = { id: user._id.toString(), name: user.name, email: user.email };
    next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ success: false, message: 'Token has expired. Please log in again.' });
    }
    if (err.name === 'JsonWebTokenError') {
      return res.status(401).json({ success: false, message: 'Invalid token.' });
    }
    next(err);
  }
};

module.exports = authMiddleware;
