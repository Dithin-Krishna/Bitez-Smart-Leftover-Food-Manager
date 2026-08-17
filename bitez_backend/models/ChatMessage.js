const mongoose = require('mongoose');

/**
 * ChatMessage Schema — stores persistent AI & user conversation history.
 */
const chatMessageSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    text: {
      type: String,
      required: true,
    },
    isUser: {
      type: Boolean,
      required: true,
      default: false,
    },
    suggestedActions: {
      type: [String],
      default: [],
    },
    status: {
      type: String,
      enum: ['sending', 'sent', 'error'],
      default: 'sent',
    },
  },
  { timestamps: true }
);

chatMessageSchema.index({ userId: 1, createdAt: 1 });

module.exports = mongoose.model('ChatMessage', chatMessageSchema);
