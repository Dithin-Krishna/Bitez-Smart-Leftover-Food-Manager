# 📋 BITEZ: Actionable TODO & Roadmap

This document outlines upcoming improvements, features, and technical tasks categorized by priority and domain.

---

## 🎯 High Priority (P0 — Immediate UX Enhancements)

- [x] **1-Tap "Add Missing Ingredients" to Grocery List**
  - *Location:* [recipe_detail_screen.dart](file:///c:/Users/dithinkrishna/Desktop/mini/bitez_app/lib/screens/recipe_detail_screen.dart) & [grocery_service.dart](file:///c:/Users/dithinkrishna/Desktop/mini/bitez_app/lib/services/grocery_service.dart)
  - *Description:* Add an action button on the recipe detail screen allowing users to add all items in the "Missing Ingredients" section directly into their MongoDB-backed Grocery List with one tap.
- [x] **"I Cooked This!" Fridge Auto-Deduction**
  - *Location:* [recipe_detail_screen.dart](file:///c:/Users/dithinkrishna/Desktop/mini/bitez_app/lib/screens/recipe_detail_screen.dart) & [fridge_service.dart](file:///c:/Users/dithinkrishna/Desktop/mini/bitez_app/lib/services/fridge_service.dart)
  - *Description:* When a user marks a recipe as completed, prompt: *"Would you like to deduct the used ingredients from your fridge?"* Automatically decrease quantity or prompt which items were finished.
- [x] **Custom Expiration Date Setter on Food Recognition**
  - *Location:* [food_confirmation_dialog.dart](file:///c:/Users/dithinkrishna/Desktop/mini/bitez_app/lib/widgets/food_confirmation_dialog.dart)
  - *Description:* Allow users to adjust the detected item's estimated expiration date before committing it into the fridge database.

---

## 🚀 Medium Priority (P1 — Analytics & Smart Features)

- [x] **Food Waste & Savings Analytics Dashboard**
  - *Description:* Track metrics:
    - Number of leftovers saved / recipes prepared.
    - Estimated money saved ($/₹) based on average ingredient cost.
    - Visual waste-reduction progress bar or monthly streak badge.
  - *Implementation:* MongoDB `CookLog` tracking in `PATCH /api/fridge/deduct`, `GET /api/analytics/waste-savings` aggregation, and `AnalyticsDashboardScreen` with streak badges, monthly milestone progress, category breakdown, and recipe history.
- [x] **Barcode & Packaged Food Scanner**
  - *Description:* Integrate `mobile_scanner` with Open Food Facts API (`https://world.openfoodfacts.org/api/v0/product/[barcode].json`) to instantly scan milk cartons, canned goods, and packaged snacks to extract expiration and nutrition data.
  - *Implementation:* `BarcodeService` with Open Food Facts parsing (product name, brand, nutrition, category, expiry), `FoodConfirmationDialog` with barcode fallback and custom date picker, and `BarcodeScannerScreen` with viewfinder and manual fallback entry.
- [x] **Weekly Meal Planner Calendar**
  - *Description:* Allow users to pin saved recipes to calendar days (Monday–Sunday) and generate consolidated grocery needs.
  - *Implementation:* MongoDB `MealPlan` model, `/api/meal-planner` routes (pin, unpin, consolidated-ingredients), `MealPlannerScreen` with 7-day Monday–Sunday planner, "Pin to Meal Plan" button in `RecipeDetailScreen`, and consolidated grocery generation integrating Feature 2 bulk deduplication.

---

## 💡 Low Priority / Future Innovation (P2 — AI & Kitchen Assistant)

- [ ] **Voice-Guided Cooking Mode (Hands-Free)**
  - *Description:* Implement text-to-speech (`flutter_tts`) and voice recognition in the cooking step viewer so users can say *"Next step"*, *"Repeat"*, or *"Set timer for 10 minutes"* with dirty hands while cooking.
- [ ] **Shared Family / Roommate Fridge Mode**
  - *Description:* Support invitation codes allowing multiple user accounts to share and synchronize a single household fridge and grocery list.
- [ ] **Nutrition & Macro Tracking**
  - *Description:* Automatically compute calories, protein, carbs, and fat for custom leftover recipes.

---

## ⚙️ Technical, DevOps & Quality (P3)

- [x] **Offline-First Synchronization (Hive)**
  - *Description:* Cache fridge items, recipes, and grocery lists locally with Hive. Queue mutations (add, update qty, delete, "I Cooked This!" deductions, grocery changes) when offline and replay in FIFO order upon reconnect. Conflicts (e.g. server-side deletions) favor server state and surface a `SyncConflictBanner` notice to the user.
- [x] **Unit & Widget Test Coverage**
  - *Description:* Add unit test suites for `RecipeService` matching algorithms, auth/fridge widgets, barcode scanner, meal planner, analytics, and offline sync/conflicts.
  - *Coverage:* 54 automated tests passing (100% pass rate).
- [x] **Production API Rate Limiting & Health Alerting**
  - *Description:* Rate limiters tailored to external API quota tiers (`geminiLimiter`, `recipeLimiter`, `authLimiter`, `apiLimiter`) with health alerting via Nodemailer when 429 limits spike or background crons (12h expiry scheduler) fail.
