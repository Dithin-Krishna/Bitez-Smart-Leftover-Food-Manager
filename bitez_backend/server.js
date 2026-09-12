const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const path = require('path');

const dotenvResult = require('dotenv').config({
  path: path.join(__dirname, '.env')
});

console.log('📁 Server directory:', __dirname);
console.log('🔐 MONGO_URI loaded:', process.env.MONGO_URI ? 'YES ✅' : 'NO ❌');

if (dotenvResult.error) {
  console.error('❌ Error loading .env:', dotenvResult.error);
}
require('dotenv').config();

const app = express();

// ── Middleware ─────────────────────────────────────────────────────────────────
app.use(cors({
  origin: '*',          // In production, replace with your Flutter app's domain or remove
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ── Production Rate Limiting ──────────────────────────────────────────────────
const { apiLimiter } = require('./middleware/rateLimiters');
app.use('/api', apiLimiter);

// ── MongoDB Atlas Connection ───────────────────────────────────────────────────
const connectDB = async () => {
  try {
    await mongoose.connect(process.env.MONGO_URI, {
      serverSelectionTimeoutMS: 5000,
    });
    console.log('✅  MongoDB Atlas connected successfully');
  } catch (err) {
    console.error('❌  MongoDB connection failed:', err.message);
    process.exit(1);
  }
};
connectDB();

// ── Routes ────────────────────────────────────────────────────────────────────
app.use('/api/auth', require('./routes/auth'));
app.use('/api/fridge', require('./routes/fridge'));
app.use('/api/recipes', require('./routes/recipes'));
app.use('/api/user', require('./routes/user'));
app.use('/api/chat', require('./routes/chat'));
app.use('/api/vision', require('./routes/vision'));
app.use('/api/grocery', require('./routes/grocery'));
app.use('/api/analytics', require('./routes/analytics'));
app.use('/api/meal-planner', require('./routes/mealPlanner'));

// ── Health check ──────────────────────────────────────────────────────────────
app.get('/', (req, res) => {
  res.json({
    status: 'OK',
    message: '🍽️  Bitez API is running',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
  });
});

// ── 404 handler ───────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ success: false, message: `Route ${req.originalUrl} not found` });
});

// ── Global error handler ──────────────────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error('🔥 Unhandled error:', err.stack);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal server error',
  });
});

// ── Expiry Notification Scheduler ─────────────────────────────────────────────
const { initExpiryScheduler } = require('./utils/expiryScheduler');

// ── Start Server ──────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀  Bitez backend running on http://0.0.0.0:${PORT}`);
  console.log(`📡  Environment: ${process.env.NODE_ENV || 'development'}`);
  initExpiryScheduler();
});
