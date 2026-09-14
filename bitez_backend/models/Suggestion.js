const mongoose = require('mongoose');

const suggestionSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    userName: {
      type: String,
      trim: true,
      default: 'Anonymous Foodie',
    },
    userEmail: {
      type: String,
      trim: true,
      default: '',
    },
    category: {
      type: String,
      enum: ['feature', 'ui_ux', 'recipe_idea', 'bug_report', 'general'],
      default: 'feature',
    },
    title: {
      type: String,
      required: [true, 'Suggestion title is required'],
      trim: true,
      maxlength: [120, 'Title cannot exceed 120 characters'],
    },
    description: {
      type: String,
      required: [true, 'Suggestion description is required'],
      trim: true,
      maxlength: [1000, 'Description cannot exceed 1000 characters'],
    },
    rating: {
      type: Number,
      min: 1,
      max: 5,
      default: 5,
    },
    status: {
      type: String,
      enum: ['under_review', 'planned', 'implemented', 'closed'],
      default: 'under_review',
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Suggestion', suggestionSchema);
