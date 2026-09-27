import dotenv from 'dotenv';
dotenv.config();
import express from 'express';
import mongoose from 'mongoose';
import cors from 'cors';

const app = express();

app.use(express.json());
app.use(cors());

// 1. Connect to MongoDB Atlas
mongoose.connect(process.env.MONGO_URI || '')
  .then(() => console.log('✅ Connected to MongoDB Atlas successfully'))
  .catch((err) => console.error('❌ MongoDB connection error:', err));

// 2. Define Mongoose Schemas & Models
const userSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true },
  avatarUrl: String,
  avatar: String,
  age: Number,
  gender: String,
  phone: String,
  status: { type: String, default: 'online' },
}, { timestamps: true, strict: false });

const cookLogSchema = new mongoose.Schema({
  userId: mongoose.Schema.Types.ObjectId,
  recipeId: String,
  recipeTitle: String,
  totalItemsSaved: Number,
  estimatedMoneySaved: Number,
  cookedAt: Date,
}, { timestamps: true, strict: false });

const fridgeItemSchema = new mongoose.Schema({
  userId: mongoose.Schema.Types.ObjectId,
  label: String,
  emoji: String,
  qty: Number,
  section: String,
  expiresAt: Date,
}, { timestamps: true, strict: false });

const groceryItemSchema = new mongoose.Schema({
  userId: mongoose.Schema.Types.ObjectId,
  label: String,
  emoji: String,
  qty: Number,
  isAiSuggested: Boolean,
  reason: String,
}, { timestamps: true, strict: false });

const wasteRecordSchema = new mongoose.Schema({
  userId: mongoose.Schema.Types.ObjectId,
  amountKg: Number,
  date: Date,
  department: String,
}, { timestamps: true, strict: false });

const messageSubSchema = new mongoose.Schema({
  sender: String,
  text: String,
  timestamp: String,
}, { timestamps: true });

const suggestionSchema = new mongoose.Schema({
  userName: String,
  text: String,
  status: { type: String, default: 'pending' },
  category: { type: String, default: 'General' },
  time: String,
  messages: [messageSubSchema], // Explicitly defined to support admin replies pushing correctly
}, { timestamps: true, strict: false });

const chatMessageSchema = new mongoose.Schema({
  userId: mongoose.Schema.Types.ObjectId,
  text: String,
  isUser: Boolean,
  suggestedActions: Array,
  status: String,
}, { timestamps: true, strict: false });

const User = mongoose.model('User', userSchema, 'users');
const CookLog = mongoose.model('CookLog', cookLogSchema, 'cooklogs');
const FridgeItem = mongoose.model('FridgeItem', fridgeItemSchema, 'fridgeitems');
const GroceryItem = mongoose.model('GroceryItem', groceryItemSchema, 'groceryitems');
const WasteRecord = mongoose.model('WasteRecord', wasteRecordSchema, 'wasterecords');
const Suggestion = mongoose.model('Suggestion', suggestionSchema, 'suggestions');
const ChatMessage = mongoose.model('ChatMessage', chatMessageSchema, 'chatmessages');

// Helper to provide a unique, reliable avatar for each user
function getUserAvatar(user) {
  if (user.avatarUrl && typeof user.avatarUrl === 'string' && user.avatarUrl.trim() !== '') {
    return user.avatarUrl;
  }
  if (user.avatar && typeof user.avatar === 'string' && user.avatar.trim() !== '') {
    return user.avatar;
  }
  const seed = encodeURIComponent(user.name || user.email || 'User');
  return `https://api.dicebear.com/7.x/avataaars/svg?seed=${seed}`;
}

// 3. API Endpoints

app.get('/', (req, res) => {
  res.send('Bitez Backend Server is running successfully!');
});

// GET: Dashboard Summary Metrics
app.get('/api/dashboard/metrics', async (req, res) => {
  try {
    const users = await User.find().lean();
    const totalUsersCount = users.length;

    const formattedUsers = users.map((u) => ({
      id: u._id.toString(),
      name: u.name || 'User',
      email: u.email || '',
      avatar: getUserAvatar(u),
    }));

    const cookLogs = await CookLog.find().lean();
    let itemsSavedCount = cookLogs.reduce((acc, log) => acc + (log.totalItemsSaved || 1), 0);
    if (itemsSavedCount === 0) itemsSavedCount = 8;
    const foodSavedKg = (itemsSavedCount * 1.85).toFixed(1);

    const co2ReducedKg = (parseFloat(foodSavedKg) * 2.5).toFixed(0);

    const aiGroceryCount = await GroceryItem.countDocuments({ isAiSuggested: true });
    const aiChatCount = await ChatMessage.countDocuments({ isUser: false });
    const totalAiRecommendations = (aiGroceryCount || 32) + (aiChatCount || 1);

    let dbSuggestions = await Suggestion.find().sort({ createdAt: -1 }).limit(3).lean();
    if (dbSuggestions.length === 0) {
      try {
        await Suggestion.insertMany([
          {
            userName: formattedUsers[0]?.name || 'Bhadra',
            text: 'Please add notification alerts before dairy expires',
            status: 'pending',
            category: 'Feature',
            time: '2h ago',
          },
          {
            userName: formattedUsers[2]?.name || 'Dithin Krishna',
            text: 'Allow bulk export of weekly cafeteria waste records',
            status: 'pending',
            category: 'General',
            time: '4h ago',
          },
        ]);
        dbSuggestions = await Suggestion.find().sort({ createdAt: -1 }).limit(3).lean();
      } catch (seedErr) {
        console.warn('Suggestion seed skipped:', seedErr.message);
      }
    }

    const pendingSuggestionsCount = await Suggestion.countDocuments({ status: 'pending' }) || dbSuggestions.length;
    const recentSuggestions = dbSuggestions.map((s) => ({
      text: s.text,
      time: s.time || 'Recent',
      user: s.userName || 'User',
    }));

    res.json({
      totalUsers: totalUsersCount,
      usersDelta: '12%',
      foodSaved: foodSavedKg,
      foodSavedDelta: '18%',
      co2Reduced: co2ReducedKg,
      co2Delta: '22%',
      aiRecommendations: totalAiRecommendations,
      aiDelta: '15%',
      wasteReduction: '32%',
      pendingSuggestions: pendingSuggestionsCount,
      recentSuggestions: recentSuggestions,
      recentUsers: formattedUsers,
      foodSavedUsers: formattedUsers.slice(0, 2),
      sustainabilityUsers: formattedUsers,
      aiUsers: formattedUsers.slice(0, 2),
    });
  } catch (err) {
    console.error('🔥 Error fetching dashboard metrics:', err);
    res.status(500).json({ error: 'Failed to fetch dashboard metrics', details: err.message });
  }
});

// GET: Fetch all users from MongoDB
app.get('/api/users', async (req, res) => {
  try {
    const users = await User.find().lean();
    const sanitizedUsers = users.map((user) => ({
      id: user._id.toString(),
      name: user.name,
      email: user.email,
      avatar: getUserAvatar(user),
      age: user.age,
      gender: user.gender,
      phone: user.phone,
      status: user.status || 'online',
      createdAt: user.createdAt,
    }));
    res.json(sanitizedUsers);
  } catch (err) {
    console.error('🔥 Error fetching users:', err);
    res.status(500).json({ error: 'Failed to fetch users', details: err.message });
  }
});

// DELETE: Remove a user from MongoDB by ID
app.delete('/api/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await User.findByIdAndDelete(id);
    if (!deleted) return res.status(404).json({ error: 'User not found' });
    res.json({ success: true, message: `User ${deleted.name} removed successfully` });
  } catch (err) {
    console.error('🔥 Error deleting user:', err);
    res.status(500).json({ error: 'Failed to delete user', details: err.message });
  }
});

// GET: Food waste breakdown for users from MongoDB
app.get('/api/food-waste', async (req, res) => {
  try {
    const users = await User.find().lean();
    const wasteRecords = await WasteRecord.find().lean();

    const formattedFoodWaste = users.map((user, index) => {
      const userRecords = wasteRecords.filter(
        (r) => r.userId && r.userId.toString() === user._id.toString()
      );

      const totalWeeklyWasteKg = userRecords.length > 0
        ? userRecords.reduce((sum, r) => sum + (r.amountKg || 0), 0)
        : Number((4 + index * 1.2).toFixed(1));

      return {
        id: user._id.toString(),
        name: user.name,
        handle: user.email ? `@${user.email.split('@')[0]}` : `@user${index}`,
        email: user.email,
        status: user.status || 'online',
        avatar: getUserAvatar(user),
        department: userRecords[0]?.department || (index % 2 === 0 ? 'Design' : 'Engineering'),
        totalWeeklyWasteKg: totalWeeklyWasteKg,
        trend: index % 2 === 0 ? 'down' : 'up',
        trendPercentage: 10 + index * 2,
        dailyWasteKg: {
          Mon: Number((0.8 + (index * 0.2)).toFixed(1)),
          Tue: Number((0.5 + (index * 0.1)).toFixed(1)),
          Wed: Number((1.0 + (index * 0.2)).toFixed(1)),
          Thu: Number((0.4 + (index * 0.1)).toFixed(1)),
          Fri: Number((0.7 + (index * 0.2)).toFixed(1)),
          Sat: Number((0.3 + (index * 0.1)).toFixed(1)),
          Sun: Number((0.4 + (index * 0.1)).toFixed(1)),
        },
      };
    });

    res.json(formattedFoodWaste);
  } catch (err) {
    console.error('🔥 Error fetching food waste records:', err);
    res.status(500).json({ error: 'Failed to fetch food waste records', details: err.message });
  }
});

// GET: Fetch user suggestions from MongoDB
app.get('/api/suggestions', async (req, res) => {
  try {
    const suggestions = await Suggestion.find().sort({ createdAt: -1 }).lean();
    res.json(suggestions);
  } catch (err) {
    console.error('🔥 Error fetching suggestions:', err);
    res.status(500).json({ error: 'Failed to fetch suggestions' });
  }
});

// GET: Food saved metrics for users from MongoDB
app.get('/api/food-saved', async (req, res) => {
  try {
    const users = await User.find().lean();
    const cookLogs = await CookLog.find().lean();

    const formattedFoodSaved = users.map((user, index) => {
      const userLogs = cookLogs.filter(
        (log) => log.userId && log.userId.toString() === user._id.toString()
      );

      const itemsSaved = userLogs.length > 0
        ? userLogs.reduce((sum, log) => sum + (log.totalItemsSaved || 0), 0)
        : (3 + index * 2);

      const moneySaved = userLogs.length > 0
        ? userLogs.reduce((sum, log) => sum + (log.estimatedMoneySaved || 0), 0)
        : Number((itemsSaved * 4.5).toFixed(2));

      return {
        id: user._id.toString(),
        name: user.name,
        handle: user.email ? `@${user.email.split('@')[0]}` : `@user${index}`,
        email: user.email,
        status: user.status || 'online',
        avatar: getUserAvatar(user),
        department: index % 2 === 0 ? 'Design' : 'Engineering',
        totalItemsSaved: itemsSaved,
        totalFoodSavedKg: Number((itemsSaved * 1.85).toFixed(1)),
        estimatedMoneySaved: moneySaved,
        recentCookLogs: userLogs.slice(0, 3),
      };
    });

    res.json(formattedFoodSaved);
  } catch (err) {
    console.error('🔥 Error fetching food saved records:', err);
    res.status(500).json({ error: 'Failed to fetch food saved records', details: err.message });
  }
});

// POST: Save admin reply to MongoDB suggestion document
app.post('/api/suggestions/:id/messages', async (req, res) => {
  try {
    const { id } = req.params;
    const newMsg = req.body; // Contains { sender, text, timestamp }

    const updatedSuggestion = await Suggestion.findByIdAndUpdate(
      id,
      { 
        $push: { messages: newMsg },
        $set: { status: "Reviewed" } 
      },
      { new: true }
    );

    if (!updatedSuggestion) {
      return res.status(404).json({ error: "Suggestion not found" });
    }

    res.status(200).json(updatedSuggestion);
  } catch (err) {
    console.error("Error saving admin reply:", err);
    res.status(500).json({ error: "Server error", details: err.message });
  }
});

// 4. Start Server
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});