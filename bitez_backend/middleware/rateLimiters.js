const rateLimit = require('express-rate-limit');
const alertService = require('../utils/alertService');

/**
 * Helper to build custom rate limiter with unified JSON format and health alerting.
 */
function createLimiter({ windowMs, max, message, limiterName }) {
  return rateLimit({
    windowMs,
    max,
    standardHeaders: true, // Return standard RateLimit-* headers
    legacyHeaders: false,  // Disable X-RateLimit-* headers
    handler: (req, res, next, options) => {
      // Record violation for health alerting
      alertService.recordRateLimitViolation(req.ip, req.originalUrl, limiterName);

      const retryAfterSeconds = Math.ceil(windowMs / 1000);
      res.status(429).json({
        success: false,
        statusCode: 429,
        message,
        retryAfter: retryAfterSeconds,
        timestamp: new Date().toISOString(),
      });
    },
  });
}

// 1. Google Gemini Vision / Chat Limiter
// Gemini Free Tier: 15 RPM / 1,500 RPD. Limit to 10 requests per minute per IP.
const geminiLimiter = createLimiter({
  windowMs: 1 * 60 * 1000,
  max: 10,
  message: 'AI request limit reached. Please wait a minute before scanning or chatting with Chef Bitez.',
  limiterName: 'Gemini AI',
});

// 2. Recipe Search & Proxy Limiter
// Spoonacular Free Tier: 150 points / day. Limit bursts to 25 requests per 15 minutes per IP.
const recipeLimiter = createLimiter({
  windowMs: 15 * 60 * 1000,
  max: 25,
  message: 'Recipe search rate limit reached. Please wait a few minutes before searching again.',
  limiterName: 'Recipe Engine',
});

// 3. Auth Endpoints Limiter (Brute-force protection)
// Limit login and registration attempts to 10 per 15 minutes per IP.
const authLimiter = createLimiter({
  windowMs: 15 * 60 * 1000,
  max: 10,
  message: 'Too many authentication attempts. Please wait 15 minutes before trying again.',
  limiterName: 'Authentication',
});

// 4. Global API Limiter
// Prevents high-volume scrapers and DDoS traffic across all endpoints.
const apiLimiter = createLimiter({
  windowMs: 15 * 60 * 1000,
  max: 300,
  message: 'Too many requests from this IP. Please slow down.',
  limiterName: 'Global API',
});

module.exports = {
  geminiLimiter,
  recipeLimiter,
  authLimiter,
  apiLimiter,
};
