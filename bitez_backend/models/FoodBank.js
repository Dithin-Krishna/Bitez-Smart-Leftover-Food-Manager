const mongoose = require('mongoose');

/**
 * FoodBank / Donation Center Schema
 * Mirrors Section 12.8 & 22 (Surplus Food Donation & Food Bank Directory)
 * in the MCA Mini Project Report.
 */
const foodBankSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Name is required'],
      trim: true,
    },
    type: {
      type: String,
      enum: ['Food Bank', 'Community Fridge', 'Shelter & Kitchen', 'NGO / Rescue'],
      default: 'Food Bank',
    },
    description: {
      type: String,
      default: '',
      trim: true,
    },
    phone: {
      type: String,
      default: '',
      trim: true,
    },
    email: {
      type: String,
      default: '',
      trim: true,
    },
    address: {
      type: String,
      required: true,
      trim: true,
    },
    city: {
      type: String,
      default: 'Kochi',
      trim: true,
    },
    operatingHours: {
      type: String,
      default: '9:00 AM - 6:00 PM',
      trim: true,
    },
    acceptedItems: {
      type: [String],
      default: ['Cooked Meals', 'Fresh Produce', 'Packaged & Dry Food'],
    },
    isVerified: {
      type: Boolean,
      default: true,
    },
    distanceKm: {
      type: Number,
      default: 2.5,
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('FoodBank', foodBankSchema);
