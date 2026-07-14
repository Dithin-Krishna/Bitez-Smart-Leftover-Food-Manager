const mongoose = require('mongoose');

/**
 * Recipe schema — stores AI-generated recipes from the home screen.
 * A recipe is linked to a user and optionally to the fridge items used.
 */
const recipeSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    title: {
      type: String,
      required: [true, 'Recipe title is required'],
      trim: true,
      maxlength: [100, 'Title too long'],
    },
    description: {
      type: String,
      trim: true,
      maxlength: [500, 'Description too long'],
    },
    ingredients: {
      type: [String],
      default: [],
    },
    steps: {
      type: [String],
      default: [],
    },
    // Fridge items used (labels only, for display)
    fridgeItemsUsed: {
      type: [String],
      default: [],
    },
    // Image URL from Cloudinary (if food photo was uploaded)
    imageUrl: {
      type: String,
      default: null,
    },
    // Base64 or URL of the input food photo the user took
    inputPhotoUrl: {
      type: String,
      default: null,
    },
    cookTime:   { type: Number, default: null },   // in minutes
    servings:   { type: Number, default: 2 },
    difficulty: {
      type: String,
      enum: ['Easy', 'Medium', 'Hard'],
      default: 'Easy',
    },
    isSaved: {
      type: Boolean,
      default: false,
      index: true,
    },
    // Raw AI response (useful for debugging)
    aiRaw: {
      type: String,
      select: false,
    },
  },
  { timestamps: true }
);

// Efficient queries for a user's saved recipes
recipeSchema.index({ userId: 1, isSaved: 1, createdAt: -1 });

module.exports = mongoose.model('Recipe', recipeSchema);
