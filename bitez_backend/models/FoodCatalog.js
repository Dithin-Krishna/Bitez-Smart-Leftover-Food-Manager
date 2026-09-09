const path = require('path');
const fs   = require('fs');

// Load official USDA FoodKeeper dataset
let FOODKEEPER_DATASET = [];
try {
  const jsonPath = path.join(__dirname, '../data/foodkeeper_dataset.json');
  if (fs.existsSync(jsonPath)) {
    const raw = fs.readFileSync(jsonPath, 'utf8');
    FOODKEEPER_DATASET = JSON.parse(raw);
  }
} catch (err) {
  console.error('Failed to load foodkeeper_dataset.json:', err.message);
}

/** Objects to immediately discard from food detection results */
const BLACKLIST = [
  'plate', 'spoon', 'fork', 'knife', 'table', 'chair', 'laptop', 'phone',
  'bottle', 'glass', 'bowl', 'utensil', 'box', 'desk', 'person', 'hand',
  'paper', 'napkin', 'cup', 'container', 'bag', 'wrapper',
];

/**
 * Returns default shelf life in days for a food item label based on USDA FoodKeeper dataset.
 * Adjusts shelf life based on storage section (refrigerated vs frozen vs pantry).
 */
function getDefaultShelfLifeDays(label, section) {
  if (!label || typeof label !== 'string') return 7;
  const clean = label.trim().toLowerCase();

  const match = FOODKEEPER_DATASET.find(
    (item) => item.name === clean || clean.includes(item.name) || item.name.includes(clean)
  );

  if (match) {
    if (section === 'frozen' && match.freezerDays > 0) {
      return match.freezerDays;
    }
    return match.refrigeratedDays || 7;
  }

  // Fallback defaults by section if item is not in the dataset
  switch (section) {
    case 'frozen':
      return 90;
    case 'dairy':
      return 7;
    case 'veggies':
      return 7;
    case 'fruits':
      return 7;
    case 'drinks':
      return 14;
    case 'condiments':
      return 30;
    default:
      return 7;
  }
}

/**
 * Validates an item name against the dataset.
 * Returns enriched item info if it looks like food, or null if it's a non-food object.
 */
function validateAndEnrich(itemName) {
  if (!itemName || typeof itemName !== 'string') return null;
  const clean = itemName.trim().toLowerCase();

  if (BLACKLIST.some((b) => clean.includes(b))) return null;

  const match = FOODKEEPER_DATASET.find(
    (item) => item.name === clean || clean.includes(item.name) || item.name.includes(clean)
  );

  if (match) {
    return {
      name: match.displayName,
      category: match.category,
      defaultSection: match.defaultSection,
      emoji: match.emoji,
      defaultShelfLifeDays: match.refrigeratedDays,
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
    defaultShelfLifeDays: 7,
    isValidated: false,
  };
}

module.exports = {
  validateAndEnrich,
  getDefaultShelfLifeDays,
  DEFAULT_CATALOG: FOODKEEPER_DATASET,
};
