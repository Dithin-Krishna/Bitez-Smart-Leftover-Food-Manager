const mongoose = require('mongoose');

/**
 * CookLog schema — logs recipe cooking events and fridge ingredient deductions.
 * Powers the Food Waste & Savings Analytics Dashboard.
 */
const cookLogSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    recipeId: {
      type: String,
      default: null,
    },
    recipeTitle: {
      type: String,
      required: true,
      trim: true,
      default: 'Delicious Meal',
    },
    deductions: [
      {
        itemId: { type: String },
        label: { type: String, required: true },
        quantityUsed: { type: Number, required: true, default: 1 },
        section: { type: String, default: 'pantry' },
        estimatedCost: { type: Number, default: 1.50 }, // average $ savings per leftover ingredient item
      },
    ],
    totalItemsSaved: {
      type: Number,
      default: 0,
    },
    estimatedMoneySaved: {
      type: Number,
      default: 0.0,
    },
    cookedAt: {
      type: Date,
      default: Date.now,
      index: true,
    },
  },
  { timestamps: true }
);

cookLogSchema.index({ userId: 1, cookedAt: -1 });

module.exports = mongoose.model('CookLog', cookLogSchema);
