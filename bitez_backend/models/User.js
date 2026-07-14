const mongoose = require('mongoose');
const bcrypt   = require('bcryptjs');

/**
 * User schema — mirrors Bitez signup form fields:
 *   name, email, age, gender, phone
 * Password is stored as a bcrypt hash (never plain text).
 */
const userSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Name is required'],
      trim: true,
      maxlength: [60, 'Name too long'],
    },
    email: {
      type: String,
      required: [true, 'Email is required'],
      unique: true,
      lowercase: true,
      trim: true,
      match: [/^\S+@\S+\.\S+$/, 'Please provide a valid email'],
    },
    passwordHash: {
      type: String,
      required: [true, 'Password is required'],
      minlength: 6,
      select: false,   // Never returned in query results by default
    },
    age: {
      type: Number,
      min: [1, 'Age must be positive'],
      max: [120, 'Age is unrealistic'],
    },
    gender: {
      type: String,
      enum: ['Female', 'Male', 'Other', 'Prefer not to say'],
    },
    phone: {
      type: String,
      trim: true,
    },
    avatarUrl: {
      type: String,
      default: null,
    },
  },
  { timestamps: true }
);

// ── Instance method: compare password ─────────────────────────────────────────
userSchema.methods.comparePassword = async function (candidatePassword) {
  return bcrypt.compare(candidatePassword, this.passwordHash);
};

// ── Pre-save hook: hash password before saving ────────────────────────────────
userSchema.pre('save', async function (next) {
  if (!this.isModified('passwordHash')) return next();
  const salt = await bcrypt.genSalt(12);
  this.passwordHash = await bcrypt.hash(this.passwordHash, salt);
  next();
});

module.exports = mongoose.model('User', userSchema);
