const mongoose = require('mongoose');

/**
 * GroceryItem schema — represents an item on the user's smart grocery shopping list.
 */
const groceryItemSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    label: {
      type: String,
      required: [true, 'Label is required'],
      trim: true,
      maxlength: [50, 'Label too long'],
    },
    emoji: {
      type: String,
      default: '🛒',
      trim: true,
    },
    qty: {
      type: Number,
      default: 1,
      min: [1, 'Quantity must be at least 1'],
    },
    category: {
      type: String,
      default: 'Produce',
      trim: true,
    },
    section: {
      type: String,
      default: 'veggies',
      trim: true,
    },
    isBought: {
      type: Boolean,
      default: false,
    },
    isAiSuggested: {
      type: Boolean,
      default: false,
    },
    reason: {
      type: String,
      default: null, // Optional AI explanation e.g. "Low in fridge" or "Restock staple"
    },
  },
  { timestamps: true }
);

groceryItemSchema.index({ userId: 1, isBought: 1 });

module.exports = mongoose.model('GroceryItem', groceryItemSchema);
