const FridgeItem = require('../models/FridgeItem');
const User       = require('../models/User');
const sendEmail  = require('./email');

/**
 * Checks all fridge items in MongoDB for items expiring within the next 24-48 hours,
 * groups them by user, and sends a notification email to each user.
 */
async function checkAndSendExpiryNotifications() {
  try {
    console.log('⏰ Running Expiry Notification Scheduler check...');

    const now = new Date();
    // Look ahead 48 hours
    const next48Hours = new Date(now.getTime() + 48 * 60 * 60 * 1000);

    // Find fridge items expiring between now and next 48 hours
    const expiringItems = await FridgeItem.find({
      expiresAt: { $gte: now, $lte: next48Hours },
    }).populate('userId', 'email name');

    if (!expiringItems || expiringItems.length === 0) {
      console.log('ℹ️ No items expiring within the next 48 hours.');
      return { count: 0, usersNotified: 0 };
    }

    // Group expiring items by user ID
    const userMap = {};
    for (const item of expiringItems) {
      if (!item.userId || !item.userId.email) continue;
      const uid = item.userId._id.toString();
      if (!userMap[uid]) {
        userMap[uid] = {
          user: item.userId,
          items: [],
        };
      }
      userMap[uid].items.push(item);
    }

    let usersNotified = 0;
    for (const uid in userMap) {
      const { user, items } = userMap[uid];
      const itemListText = items
        .map((i) => {
          const daysLeft = Math.ceil((new Date(i.expiresAt) - now) / (1000 * 60 * 60 * 24));
          const timeStr = daysLeft <= 1 ? 'today/tomorrow' : `in ${daysLeft} days`;
          return `• ${i.emoji || '🍽️'} ${i.label} (Qty: ${i.qty}) — Expiring ${timeStr}`;
        })
        .join('\n');

      const message = `Hi ${user.name || 'Foodie'},\n\nYou have ${items.length} item(s) in your Bitez fridge that will expire soon:\n\n${itemListText}\n\nBe sure to use them in a recipe before they spoil!\n\nHappy cooking,\nThe Bitez Team`;

      try {
        await sendEmail({
          email: user.email,
          subject: `⚠️ Bitez Expiry Alert: ${items.length} item(s) expiring soon!`,
          message: message,
        });
        usersNotified++;
      } catch (emailErr) {
        console.error(`Failed to send expiry email to ${user.email}:`, emailErr.message);
      }
    }

    console.log(`✅ Expiry notification check completed. Notified ${usersNotified} user(s).`);
    return { count: expiringItems.length, usersNotified };
  } catch (err) {
    console.error('🔥 Error running expiry notification scheduler:', err);
    throw err;
  }
}

/**
 * Initializes a periodic interval check (runs every 12 hours).
 */
function initExpiryScheduler() {
  // Run once on startup after 10 seconds delay
  setTimeout(() => {
    checkAndSendExpiryNotifications().catch(() => {});
  }, 10000);

  // Run every 12 hours (12 * 60 * 60 * 1000 ms)
  const TWELVE_HOURS = 12 * 60 * 60 * 1000;
  setInterval(() => {
    checkAndSendExpiryNotifications().catch(() => {});
  }, TWELVE_HOURS);
}

module.exports = {
  checkAndSendExpiryNotifications,
  initExpiryScheduler,
};
