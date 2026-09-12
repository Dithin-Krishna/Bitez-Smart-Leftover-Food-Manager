const mongoose = require('mongoose');

/**
 * WasteRecord schema — mirrors Section 12.3 in the MCA Project Report:
 * Logs discarded food items with specific waste reasons and metrics.
 */
const wasteRecordSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    foodItemId: {
      type: String,
      default: null,
    },
    foodName: {
      type: String,
      required: [true, 'Food name is required'],
      trim: true,
    },
    category: {
      type: String,
      enum: ['Dairy', 'Vegetables', 'Fruits', 'Meat', 'Bakery', 'Pantry', 'Prepared Food', 'Other'],
      default: 'Other',
    },
    quantity: {
      type: Number,
      default: 1,
      min: [0.1, 'Quantity must be greater than zero'],
    },
    unit: {
      type: String,
      trim: true,
      default: 'item',
    },
    reason: {
      type: String,
      enum: ['Expired', 'Spoiled', 'Excess quantity', 'Forgotten food', 'Preparation error', 'Other'],
      default: 'Expired',
      required: [true, 'Waste reason is required'],
    },
    estimatedCost: {
      type: Number,
      default: 2.0, // estimated $ value per discarded item
    },
    date: {
      type: Date,
      default: Date.now,
      index: true,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('WasteRecord', wasteRecordSchema);
