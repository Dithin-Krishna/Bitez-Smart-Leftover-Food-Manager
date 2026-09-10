const mongoose = require('mongoose');

/**
 * MealPlan schema — allows users to pin recipes to days of the week (Monday–Sunday)
 * and generate consolidated grocery lists.
 */
const mealPlanSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    dayOfWeek: {
      type: String,
      enum: ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'],
      required: true,
    },
    recipeId: {
      type: String,
      default: null,
    },
    recipeTitle: {
      type: String,
      required: true,
      trim: true,
    },
    imageUrl: {
      type: String,
      default: null,
    },
    ingredients: {
      type: [String],
      default: [],
    },
    cookTime: {
      type: Number,
      default: 20,
    },
    mealType: {
      type: String,
      enum: ['breakfast', 'lunch', 'dinner', 'snack'],
      default: 'dinner',
    },
    servings: {
      type: Number,
      default: 2,
    },
  },
  { timestamps: true }
);

mealPlanSchema.index({ userId: 1, dayOfWeek: 1 });

module.exports = mongoose.model('MealPlan', mealPlanSchema);
