const mongoose = require('mongoose');

/**
 * FridgeItem schema — maps 1-to-1 to the Map<String, dynamic> structure
 * used in fridge_screen.dart:
 *   { emoji, label, qty, color }
 *
 * Each item belongs to exactly one user and one section:
 *   frozen | dairy | veggies | fruits | drinks | condiments
 */
const fridgeItemSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    emoji: {
      type: String,
      required: [true, 'Emoji is required'],
      trim: true,
    },
    label: {
      type: String,
      required: [true, 'Label is required'],
      trim: true,
      maxlength: [40, 'Label too long'],
    },
    qty: {
      type: Number,
      default: 1,
      min: [0, 'Quantity cannot be negative'],
    },
    // Stored as an integer (Dart Color.value — ARGB int)
    color: {
      type: Number,
      default: 0xFF2A4E7C,
    },
    section: {
      type: String,
      enum: {
        values: ['frozen', 'dairy', 'veggies', 'fruits', 'drinks', 'condiments'],
        message: '{VALUE} is not a valid section',
      },
      required: [true, 'Section is required'],
      index: true,
    },
    // Optional: expiry date for waste-tracking feature
    expiresAt: {
      type: Date,
      default: null,
    },
    // Optional: manufacturing date
    manufacturingDate: {
      type: Date,
      default: null,
    },
    // Optional: Base64 or image URL stored in Expiry Vault
    expiryImage: {
      type: String,
      default: null,
    },
    // Optional notes e.g., "Opened on 10 Aug", "Best before batch #4"
    expiryNotes: {
      type: String,
      default: '',
      trim: true,
    },
  },
  { timestamps: true }
);

// Compound index so we can quickly fetch all items for a user in a section
fridgeItemSchema.index({ userId: 1, section: 1 });

module.exports = mongoose.model('FridgeItem', fridgeItemSchema);
