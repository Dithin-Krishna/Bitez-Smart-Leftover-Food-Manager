/**
 * FoodCatalog — in-memory food validation catalog.
 * No database involved. Used by vision.js and grocery.js to validate
 * and enrich detected food item names with emoji, category, and section.
 */

const DEFAULT_CATALOG = [
  // Fruits
  { name: 'apple',       displayName: 'Apple',       category: 'Fruits',     defaultSection: 'fruits',      emoji: '🍎' },
  { name: 'banana',      displayName: 'Banana',      category: 'Fruits',     defaultSection: 'fruits',      emoji: '🍌' },
  { name: 'orange',      displayName: 'Orange',      category: 'Fruits',     defaultSection: 'fruits',      emoji: '🍊' },
  { name: 'strawberry',  displayName: 'Strawberry',  category: 'Fruits',     defaultSection: 'fruits',      emoji: '🍓' },
  { name: 'grape',       displayName: 'Grape',       category: 'Fruits',     defaultSection: 'fruits',      emoji: '🍇' },
  { name: 'lemon',       displayName: 'Lemon',       category: 'Fruits',     defaultSection: 'fruits',      emoji: '🍋' },
  { name: 'watermelon',  displayName: 'Watermelon',  category: 'Fruits',     defaultSection: 'fruits',      emoji: '🍉' },
  { name: 'mango',       displayName: 'Mango',       category: 'Fruits',     defaultSection: 'fruits',      emoji: '🥭' },
  { name: 'pineapple',   displayName: 'Pineapple',   category: 'Fruits',     defaultSection: 'fruits',      emoji: '🍍' },
  { name: 'peach',       displayName: 'Peach',       category: 'Fruits',     defaultSection: 'fruits',      emoji: '🍑' },
  { name: 'pear',        displayName: 'Pear',        category: 'Fruits',     defaultSection: 'fruits',      emoji: '🍐' },
  { name: 'cherry',      displayName: 'Cherry',      category: 'Fruits',     defaultSection: 'fruits',      emoji: '🍒' },
  { name: 'kiwi',        displayName: 'Kiwi',        category: 'Fruits',     defaultSection: 'fruits',      emoji: '🥝' },
  { name: 'blueberry',   displayName: 'Blueberry',   category: 'Fruits',     defaultSection: 'fruits',      emoji: '🫐' },
  { name: 'coconut',     displayName: 'Coconut',     category: 'Fruits',     defaultSection: 'fruits',      emoji: '🥥' },

  // Vegetables
  { name: 'tomato',      displayName: 'Tomato',      category: 'Vegetables', defaultSection: 'veggies',     emoji: '🍅' },
  { name: 'potato',      displayName: 'Potato',      category: 'Vegetables', defaultSection: 'veggies',     emoji: '🥔' },
  { name: 'onion',       displayName: 'Onion',       category: 'Vegetables', defaultSection: 'veggies',     emoji: '🧅' },
  { name: 'carrot',      displayName: 'Carrot',      category: 'Vegetables', defaultSection: 'veggies',     emoji: '🥕' },
  { name: 'broccoli',    displayName: 'Broccoli',    category: 'Vegetables', defaultSection: 'veggies',     emoji: '🥦' },
  { name: 'cucumber',    displayName: 'Cucumber',    category: 'Vegetables', defaultSection: 'veggies',     emoji: '🥒' },
  { name: 'eggplant',    displayName: 'Eggplant',    category: 'Vegetables', defaultSection: 'veggies',     emoji: '🍆' },
  { name: 'capsicum',    displayName: 'Capsicum',    category: 'Vegetables', defaultSection: 'veggies',     emoji: '🫑' },
  { name: 'bell pepper', displayName: 'Bell Pepper', category: 'Vegetables', defaultSection: 'veggies',     emoji: '🫑' },
  { name: 'corn',        displayName: 'Corn',        category: 'Vegetables', defaultSection: 'veggies',     emoji: '🌽' },
  { name: 'garlic',      displayName: 'Garlic',      category: 'Vegetables', defaultSection: 'veggies',     emoji: '🧄' },
  { name: 'mushroom',    displayName: 'Mushroom',    category: 'Vegetables', defaultSection: 'veggies',     emoji: '🍄' },
  { name: 'spinach',     displayName: 'Spinach',     category: 'Vegetables', defaultSection: 'veggies',     emoji: '🥬' },
  { name: 'lettuce',     displayName: 'Lettuce',     category: 'Vegetables', defaultSection: 'veggies',     emoji: '🥬' },
  { name: 'cabbage',     displayName: 'Cabbage',     category: 'Vegetables', defaultSection: 'veggies',     emoji: '🥬' },
  { name: 'cauliflower', displayName: 'Cauliflower', category: 'Vegetables', defaultSection: 'veggies',     emoji: '🥦' },
  { name: 'ginger',      displayName: 'Ginger',      category: 'Vegetables', defaultSection: 'veggies',     emoji: '🫚' },
  { name: 'chili',       displayName: 'Chili',       category: 'Vegetables', defaultSection: 'veggies',     emoji: '🌶️' },
  { name: 'peas',        displayName: 'Peas',        category: 'Vegetables', defaultSection: 'veggies',     emoji: '🫛' },
  { name: 'beans',       displayName: 'Beans',       category: 'Vegetables', defaultSection: 'veggies',     emoji: '🫘' },
  { name: 'sweet potato',displayName: 'Sweet Potato',category: 'Vegetables', defaultSection: 'veggies',     emoji: '🍠' },

  // Dairy & Eggs
  { name: 'milk',        displayName: 'Milk',        category: 'Dairy',      defaultSection: 'dairy',       emoji: '🥛' },
  { name: 'cheese',      displayName: 'Cheese',      category: 'Dairy',      defaultSection: 'dairy',       emoji: '🧀' },
  { name: 'butter',      displayName: 'Butter',      category: 'Dairy',      defaultSection: 'dairy',       emoji: '🧈' },
  { name: 'yogurt',      displayName: 'Yogurt',      category: 'Dairy',      defaultSection: 'dairy',       emoji: '🥛' },
  { name: 'egg',         displayName: 'Egg',         category: 'Dairy',      defaultSection: 'dairy',       emoji: '🥚' },
  { name: 'cream',       displayName: 'Cream',       category: 'Dairy',      defaultSection: 'dairy',       emoji: '🥛' },

  // Bakery & Grains
  { name: 'bread',       displayName: 'Bread',       category: 'Bakery',     defaultSection: 'condiments',  emoji: '🍞' },
  { name: 'bun',         displayName: 'Bun',         category: 'Bakery',     defaultSection: 'condiments',  emoji: '🥯' },
  { name: 'rice',        displayName: 'Rice',        category: 'Grains',     defaultSection: 'condiments',  emoji: '🍚' },
  { name: 'pasta',       displayName: 'Pasta',       category: 'Grains',     defaultSection: 'condiments',  emoji: '🍝' },
  { name: 'oats',        displayName: 'Oats',        category: 'Grains',     defaultSection: 'condiments',  emoji: '🌾' },

  // Meat & Seafood
  { name: 'chicken',     displayName: 'Chicken',     category: 'Meat',       defaultSection: 'frozen',      emoji: '🍗' },
  { name: 'fish',        displayName: 'Fish',        category: 'Meat',       defaultSection: 'frozen',      emoji: '🐟' },
  { name: 'meat',        displayName: 'Meat',        category: 'Meat',       defaultSection: 'frozen',      emoji: '🥩' },
  { name: 'bacon',       displayName: 'Bacon',       category: 'Meat',       defaultSection: 'frozen',      emoji: '🥓' },
  { name: 'shrimp',      displayName: 'Shrimp',      category: 'Meat',       defaultSection: 'frozen',      emoji: '🦐' },
  { name: 'salmon',      displayName: 'Salmon',      category: 'Meat',       defaultSection: 'frozen',      emoji: '🍣' },

  // Beverages
  { name: 'juice',       displayName: 'Juice',       category: 'Beverages',  defaultSection: 'drinks',      emoji: '🧃' },
  { name: 'water',       displayName: 'Water',       category: 'Beverages',  defaultSection: 'drinks',      emoji: '💧' },
  { name: 'soda',        displayName: 'Soda',        category: 'Beverages',  defaultSection: 'drinks',      emoji: '🥤' },
  { name: 'coffee',      displayName: 'Coffee',      category: 'Beverages',  defaultSection: 'drinks',      emoji: '☕' },
  { name: 'tea',         displayName: 'Tea',         category: 'Beverages',  defaultSection: 'drinks',      emoji: '🍵' },

  // Condiments & Sauces
  { name: 'ketchup',     displayName: 'Ketchup',     category: 'Condiments', defaultSection: 'condiments',  emoji: '🥫' },
  { name: 'sauce',       displayName: 'Sauce',       category: 'Condiments', defaultSection: 'condiments',  emoji: '🥫' },
  { name: 'oil',         displayName: 'Oil',         category: 'Condiments', defaultSection: 'condiments',  emoji: '🫙' },
  { name: 'vinegar',     displayName: 'Vinegar',     category: 'Condiments', defaultSection: 'condiments',  emoji: '🫙' },

  // Cooked / Frozen Foods
  { name: 'pizza',       displayName: 'Pizza',       category: 'Cooked Food',defaultSection: 'frozen',      emoji: '🍕' },
  { name: 'burger',      displayName: 'Burger',      category: 'Cooked Food',defaultSection: 'frozen',      emoji: '🍔' },
  { name: 'soup',        displayName: 'Soup',        category: 'Cooked Food',defaultSection: 'veggies',     emoji: '🍲' },
  { name: 'salad',       displayName: 'Salad',       category: 'Cooked Food',defaultSection: 'veggies',     emoji: '🥗' },
];

/** Objects to immediately discard from food detection results */
const BLACKLIST = [
  'plate', 'spoon', 'fork', 'knife', 'table', 'chair', 'laptop', 'phone',
  'bottle', 'glass', 'bowl', 'utensil', 'box', 'desk', 'person', 'hand',
  'paper', 'napkin', 'cup', 'container', 'bag', 'wrapper',
];

/**
 * Validates an item name against the catalog.
 * Returns enriched item info if it looks like food, or null if it's a non-food object.
 *
 * @param {string} itemName
 * @returns {{ name, category, defaultSection, emoji, isValidated } | null}
 */
function validateAndEnrich(itemName) {
  if (!itemName || typeof itemName !== 'string') return null;
  const clean = itemName.trim().toLowerCase();

  if (BLACKLIST.some((b) => clean.includes(b))) return null;

  const match = DEFAULT_CATALOG.find(
    (item) => item.name === clean || clean.includes(item.name) || item.name.includes(clean)
  );

  if (match) {
    return {
      name: match.displayName,
      category: match.category,
      defaultSection: match.defaultSection,
      emoji: match.emoji,
      isValidated: true,
    };
  }

  // Unknown but not blacklisted — pass through with defaults
  const capitalized = itemName.trim().charAt(0).toUpperCase() + itemName.trim().slice(1).toLowerCase();
  return {
    name: capitalized,
    category: 'Other Food',
    defaultSection: 'veggies',
    emoji: '🥗',
    isValidated: false,
  };
}

module.exports = { validateAndEnrich, DEFAULT_CATALOG };
