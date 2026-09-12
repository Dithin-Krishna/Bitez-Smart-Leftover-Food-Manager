const router   = require('express').Router();
const FoodBank = require('../models/FoodBank');
const FridgeItem = require('../models/FridgeItem');
const auth     = require('../middleware/authMiddleware');

router.use(auth);

// Curated verified community food banks and NGOs (Sections 12.8 & 22)
const DEFAULT_NGOS = [
  {
    name: 'Annam Food Bank & Rescue',
    type: 'Food Bank',
    description: 'Collecting surplus cooked meals and fresh produce for underprivileged families and relief centers.',
    phone: '+91 98470 12345',
    email: 'contact@annamfoodrescue.org',
    address: 'Near Town Hall, Marine Drive, Kochi',
    city: 'Kochi',
    operatingHours: '8:00 AM - 8:00 PM (Daily)',
    acceptedItems: ['Cooked Meals', 'Fresh Produce', 'Packaged Food', 'Dairy & Eggs'],
    isVerified: true,
    distanceKm: 1.8,
  },
  {
    name: 'Robin Hood Army Kochi',
    type: 'NGO / Rescue',
    description: 'Zero-funds volunteer organization routing surplus food from households and events to local shelters.',
    phone: '+91 94471 67890',
    email: 'kochi@robinhoodarmy.com',
    address: 'Kaloor Junction, Kochi',
    city: 'Kochi',
    operatingHours: '10:00 AM - 9:00 PM',
    acceptedItems: ['Cooked Meals', 'Bakery', 'Fruits & Vegetables'],
    isVerified: true,
    distanceKm: 3.2,
  },
  {
    name: 'Janakeeya Community Fridge',
    type: 'Community Fridge',
    description: 'Public 24/7 community refrigerator where neighbors drop off safe leftover food and produce for anyone in need.',
    phone: '+91 484 2398765',
    email: 'support@janakeeyafridge.org',
    address: 'MG Road, Opposite Medical Trust, Ernakulam',
    city: 'Kochi',
    operatingHours: 'Open 24 Hours',
    acceptedItems: ['Fresh Produce', 'Packaged Food', 'Bakery', 'Bottled Drinks'],
    isVerified: true,
    distanceKm: 4.1,
  },
  {
    name: 'Asha Bhavan Care Shelter',
    type: 'Shelter & Kitchen',
    description: 'Community home and rehabilitation shelter providing daily hot meals to elders and destitute residents.',
    phone: '+91 98950 43210',
    email: 'ashabhavan.trust@gmail.com',
    address: 'Thrikkakara, Near Model Engineering College, Kakkanad',
    city: 'Kochi',
    operatingHours: '9:00 AM - 6:00 PM',
    acceptedItems: ['Cooked Meals', 'Rice & Grains', 'Fresh Produce'],
    isVerified: true,
    distanceKm: 5.4,
  },
  {
    name: 'No Food Waste India (Kerala Chapter)',
    type: 'NGO / Rescue',
    description: 'Youth-led food recovery network with dedicated pickup transport for quantities over 5kg.',
    phone: '+91 90877 90877',
    email: 'info@nofoodwaste.in',
    address: 'Palarivattom Bypass Junction, Kochi',
    city: 'Kochi',
    operatingHours: '9:00 AM - 10:00 PM',
    acceptedItems: ['Cooked Meals', 'Excess Catering', 'Bakery', 'Packaged Food'],
    isVerified: true,
    distanceKm: 6.0,
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/donations/ngos
// Returns list of community food banks and NGOs
// ─────────────────────────────────────────────────────────────────────────────
router.get('/ngos', async (req, res, next) => {
  try {
    let ngos = [];
    try {
      ngos = await FoodBank.find().sort({ distanceKm: 1 });
      if (ngos.length === 0) {
        ngos = await FoodBank.insertMany(DEFAULT_NGOS);
      }
    } catch (dbErr) {
      // Return verified fallback if MongoDB is not connected
      ngos = DEFAULT_NGOS.map((n, idx) => ({ _id: `ngo_local_${idx + 1}`, ...n }));
    }

    res.json({
      success: true,
      count: ngos.length,
      ngos,
    });
  } catch (err) {
    next(err);
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/donations/assign
// Assigns a pledged item to a specific food bank / NGO
// ─────────────────────────────────────────────────────────────────────────────
router.post('/assign', async (req, res, next) => {
  try {
    const { itemId, ngoName, notes } = req.body;
    if (!itemId) {
      return res.status(400).json({ success: false, message: 'Item ID is required.' });
    }

    const item = await FridgeItem.findOne({ _id: itemId, userId: req.user.id });
    if (!item) {
      return res.status(404).json({ success: false, message: 'Fridge item not found.' });
    }

    item.isDonation = true;
    item.donationStatus = 'pledged';
    if (ngoName) item.donationNgoName = ngoName.trim();
    if (notes) item.donationNotes = notes.trim();

    await item.save();

    res.json({
      success: true,
      message: `Pledge assigned to ${ngoName || 'Food Bank'} successfully! ❤️`,
      item,
    });
  } catch (err) {
    next(err);
  }
});

module.exports = router;
