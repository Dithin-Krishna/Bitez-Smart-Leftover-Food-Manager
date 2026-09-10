const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/authMiddleware');
const { geminiLimiter } = require('../middleware/rateLimiters');
const FridgeItem = require('../models/FridgeItem');
const User = require('../models/User');
const ChatMessage = require('../models/ChatMessage');

/**
 * GET /api/chat/history
 * Fetch user's persistent chat history.
 */
router.get('/history', authMiddleware, async (req, res, next) => {
  try {
    const history = await ChatMessage.find({ userId: req.user.id })
      .sort({ createdAt: 1 })
      .limit(50)
      .lean();

    return res.json({
      success: true,
      data: history.map((item) => ({
        id: item._id.toString(),
        text: item.text,
        isUser: item.isUser,
        timestamp: item.createdAt,
        suggestedActions: item.suggestedActions || [],
      })),
    });
  } catch (err) {
    next(err);
  }
});

/**
 * DELETE /api/chat/history
 * Clear user's stored chat history.
 */
router.delete('/history', authMiddleware, async (req, res, next) => {
  try {
    await ChatMessage.deleteMany({ userId: req.user.id });
    return res.json({
      success: true,
      message: 'Chat history cleared successfully.',
    });
  } catch (err) {
    next(err);
  }
});

/**
 * DELETE /api/chat/message/:id
 * Delete a specific chat message from MongoDB.
 */
router.delete('/message/:id', authMiddleware, async (req, res, next) => {
  try {
    const deleted = await ChatMessage.findOneAndDelete({
      _id: req.params.id,
      userId: req.user.id,
    });

    if (!deleted) {
      return res.status(404).json({
        success: false,
        message: 'Message not found or unauthorized.',
      });
    }

    return res.json({
      success: true,
      message: 'Message deleted from database.',
    });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /api/chat/send
 * Chat endpoint for Chef Bitez AI Assistant.
 * Expects: { message: string, history?: Array<{role: 'user'|'model', text: string}> }
 */
router.post('/send', authMiddleware, geminiLimiter, async (req, res, next) => {
  try {
    const { message, history = [] } = req.body;

    if (!message || typeof message !== 'string' || !message.trim()) {
      return res.status(400).json({
        success: false,
        message: 'A message string is required.',
      });
    }

    // Save user's message to MongoDB
    const userMsgDoc = await ChatMessage.create({
      userId: req.user.id,
      text: message.trim(),
      isUser: true,
    });

    // 1. Fetch user's current fridge inventory for context
    const fridgeItems = await FridgeItem.find({ userId: req.user.id })
      .select('label section qty expiresAt')
      .lean();

    const inventoryList = fridgeItems.length > 0
      ? fridgeItems.map((item) => `- ${item.label} (Qty: ${item.qty}, Section: ${item.section})`).join('\n')
      : 'No items currently saved in fridge.';

    // 2. Fetch user dietary preferences if available
    const userDoc = await User.findById(req.user.id).select('dietaryPreference maxCookingTime').lean();
    const prefsText = userDoc
      ? `Dietary preference: ${userDoc.dietaryPreference || 'None'}, Preferred max cooking time: ${userDoc.maxCookingTime || 30} mins.`
      : 'No specific preferences saved.';

    const systemPrompt = `You are Chef Bitez 🍳, a friendly, passionate, zero-waste culinary AI assistant inside the Bitez Smart Leftover Food Manager app.
Your goals:
1. Help users cook amazing meals using ingredients currently in their fridge to eliminate food waste.
2. Provide practical food storage, shelf-life extension, and ingredient substitution advice.
3. Suggest clear, step-by-step recipes when asked. Format ingredient lists and instructions with markdown bullet points and bold headers.
4. Keep answers friendly, inspiring, concise, and structured.

USER CONTEXT:
User's Current Fridge Inventory:
${inventoryList}

User Preferences:
${prefsText}`;

    const geminiKey = process.env.GEMINI_API_KEY;

    let aiReply = '';

    if (geminiKey) {
      try {
        // Construct conversation contents for Gemini API v1beta
        const contents = [
          {
            role: 'user',
            parts: [{ text: `${systemPrompt}\n\nPlease address the following prompt from the user.` }]
          },
          {
            role: 'model',
            parts: [{ text: `Hello ${req.user.name || 'there'}! I'm Chef Bitez 🍳, your zero-waste smart cooking assistant. How can I help you transform your leftovers today?` }]
          }
        ];

        // Append recent chat history
        for (const item of history.slice(-6)) {
          contents.push({
            role: item.role === 'user' ? 'user' : 'model',
            parts: [{ text: item.text }]
          });
        }

        // Add current user prompt
        contents.push({
          role: 'user',
          parts: [{ text: message }]
        });

        const candidateModels = ['gemini-flash-latest', 'gemini-2.0-flash-lite', 'gemini-2.5-flash-lite', 'gemini-2.0-flash'];
        for (const modelName of candidateModels) {
          try {
            const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${geminiKey}`;
            const response = await fetch(geminiUrl, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ contents }),
            });

            if (response.ok) {
              const data = await response.json();
              const candidateText = data.candidates?.[0]?.content?.parts?.[0]?.text;
              if (candidateText) {
                aiReply = candidateText.trim();
                break;
              }
            } else {
              const errText = await response.text();
              console.warn(`Gemini chat model ${modelName} returned status ${response.status}:`, errText);
            }
          } catch (err) {
            console.error(`Error calling Gemini API (${modelName}):`, err.message);
          }
        }
      } catch (err) {
        console.error('Error in chat setup:', err.message);
      }
    }

    // Fallback response generator if Gemini API key is missing or API failed
    if (!aiReply) {
      aiReply = generateFallbackReply(message, fridgeItems, req.user.name);
    }

    // Suggest quick follow-up actions based on user message
    const suggestedActions = getSuggestedActions(message);

    // Save AI reply message to MongoDB
    const aiMsgDoc = await ChatMessage.create({
      userId: req.user.id,
      text: aiReply,
      isUser: false,
      suggestedActions,
    });

    return res.json({
      success: true,
      data: {
        id: aiMsgDoc._id.toString(),
        userMessageId: userMsgDoc._id.toString(),
        reply: aiReply,
        timestamp: aiMsgDoc.createdAt,
        suggestedActions,
      },
    });

  } catch (err) {
    next(err);
  }
});

/**
 * Intelligent local response fallback when no Gemini key is provided or network fails.
 */
function generateFallbackReply(userMsg, fridgeItems, userName) {
  const query = userMsg.toLowerCase();
  const itemNames = fridgeItems.map((i) => i.label.toLowerCase());

  if (query.includes('expir') || query.includes('waste') || query.includes('spoil')) {
    return `### 🧊 Zero-Waste & Expiry Guide

Hey ${userName || 'there'}! Here are some key tips to prevent food waste with your current fridge items:

- **Dairy & Milk**: Store on lower shelf (colder area), not in door racks. Freeze leftover cheese or butter if needed.
- **Vegetables & Greens**: Wrap leafy greens in paper towels in airtight containers to absorb excess moisture.
- **Produce Surplus**: Puree expiring vegetables into soups, stews, or pasta sauces.

${itemNames.length ? `You currently have **${itemNames.slice(0, 4).join(', ')}** in your fridge. Would you like a quick recipe using any of these?` : 'Add items to your Fridge tab to get personalized expiry suggestions!'}`;
  }

  if (query.includes('recipe') || query.includes('cook') || query.includes('make') || query.includes('dish') || query.includes('dinner')) {
    if (itemNames.length > 0) {
      const mainItems = itemNames.slice(0, 3).join(', ');
      return `### 🍳 Leftover Special: Chef Bitez Quick Stir-Fry / Bowl

Great news! Based on your fridge inventory (**${mainItems}**), here is a delicious 15-minute recipe:

#### Ingredients
- **Main**: ${fridgeItems.slice(0, 3).map((i) => i.label).join(', ')}
- **Pantry staples**: 1 tbsp oil, garlic/onion, soy sauce or salt & pepper, cooked rice or pasta.

#### Quick Steps
1. **Prep**: Chop your ${fridgeItems[0]?.label || 'ingredients'} into bite-sized pieces.
2. **Sauté**: Heat 1 tbsp oil in a skillet over medium-high heat. Add garlic/onion until fragrant.
3. **Combine**: Toss in your veggies and proteins. Sauté for 5–7 minutes until tender.
4. **Season**: Drizzle with soy sauce or your favorite seasoning blend. Serve hot!

*Tip: Add a fried egg on top for extra protein!*`;
    }
    return `### 🍳 Simple Fridge-Clearing Pasta / Bowl

Since your fridge inventory is empty right now, here is a classic 3-ingredient rescue recipe:

#### Ingredients
- 200g Pasta or Noodles
- 2 tbsp Olive Oil or Butter
- Garlic, Parmesan, or any vegetable/sauce you have on hand

#### Instructions
1. Boil pasta in salted water for 8–10 minutes.
2. Sauté minced garlic in olive oil.
3. Toss pasta in garlic oil with a splash of pasta water until glossy.

*Pro-tip: Add your fridge inventory items into Bitez so I can give custom recipes tailored to your exact ingredients!*`;
  }

  if (query.includes('store') || query.includes('keep') || query.includes('fresh') || query.includes('freeze')) {
    return `### 🌿 Ingredient Storage Best Practices

Here are top rules for maximum freshness:
1. **Herbs & Scallions**: Place stems in a glass of water like flowers, or chop and freeze in olive oil ice cube trays.
2. **Berries**: Wash in a 1:3 vinegar-water bath right before eating, or store dry in lined containers.
3. **Avocados**: Keep on counter until ripe, then move to fridge to halt over-ripening.
4. **Leftover Cooked Meals**: Store in airtight glass containers and consume within 3–4 days or freeze up to 3 months.`;
  }

  if (query.includes('substitute') || query.includes('replace') || query.includes('instead')) {
    return `### 🔄 Smart Ingredient Substitutions

Here are common culinary swaps:
- **Egg Substitute**: 1/4 cup applesauce or 1 tbsp flaxseed + 3 tbsp water per egg.
- **Heavy Cream**: Full-fat coconut milk OR equal parts milk + melted butter.
- **Buttermilk**: 1 cup milk + 1 tbsp lemon juice or white vinegar (let sit 5 mins).
- **Soy Sauce**: Tamari, Coconut Aminos, or Worcestershire sauce + pinch of salt.`;
  }

  return `### 🍳 Chef Bitez AI Assistant

Hello ${userName || 'there'}! I'm here to help you get the most out of your food inventory:

- 🥗 **Custom Recipes**: Tell me what you're craving or ask for recipes using your fridge items (**${itemNames.length ? itemNames.slice(0, 3).join(', ') : 'no items added yet'}**).
- 🧊 **Expiry & Waste Tips**: Ask how to store specific foods to make them last longer.
- 🔄 **Substitutions**: Missing an ingredient? Ask me for easy alternatives!

What would you like to cook or check today?`;
}

/**
 * Returns quick suggestion chips for the UI.
 */
function getSuggestedActions(userMsg) {
  const query = userMsg.toLowerCase();
  if (query.includes('recipe') || query.includes('cook')) {
    return ['Storage Tips', 'Quick 10-min Meal', 'Zero Waste Tips'];
  }
  return ['Recipe from Fridge Items', 'How to Store Foods', 'Ingredient Substitutions'];
}

module.exports = router;
