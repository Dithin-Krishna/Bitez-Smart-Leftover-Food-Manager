# 🍽️ Bitez Backend

REST API for the **Bitez** Flutter app.  
Stack: **Node.js · Express · MongoDB Atlas · JWT Auth · Cloudinary**

---

## Quick Start

```bash
# 1. Install dependencies
npm install

# 2. Set up environment
cp .env.example .env
# Edit .env with your MongoDB Atlas URI and JWT secret

# 3. Run in development (auto-reload)
npm run dev

# 4. Run in production
npm start
```

The server starts at: `http://localhost:3000`  
Health check: `GET http://localhost:3000/`

---

## Project Structure

```
bitez-backend/
├── server.js                 ← Entry point
├── .env.example              ← Environment variable template
├── models/
│   ├── User.js               ← name, email, age, gender, phone
│   ├── FridgeItem.js         ← emoji, label, qty, color, section
│   └── Recipe.js             ← AI-generated recipes
├── routes/
│   ├── auth.js               ← /api/auth/register | login | refresh
│   ├── fridge.js             ← /api/fridge  (CRUD + bulk + qty patch)
│   ├── recipes.js            ← /api/recipes (CRUD + save toggle)
│   └── user.js               ← /api/user/me (profile + password)
├── middleware/
│   └── authMiddleware.js     ← JWT verification
└── utils/
    └── cloudinary.js         ← Image upload helper
```

---

## API Reference

### Auth
| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| POST | `/api/auth/register` | ❌ | Create account |
| POST | `/api/auth/login` | ❌ | Login, get JWT |
| POST | `/api/auth/refresh` | ❌ | Refresh JWT |

### Fridge
| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| GET | `/api/fridge` | ✅ | Get all items (+ `?section=dairy`) |
| POST | `/api/fridge` | ✅ | Add one item |
| POST | `/api/fridge/bulk` | ✅ | Bulk seed items |
| PUT | `/api/fridge/:id` | ✅ | Update item |
| PATCH | `/api/fridge/:id/qty` | ✅ | Increment/decrement qty |
| DELETE | `/api/fridge/:id` | ✅ | Delete one item |
| DELETE | `/api/fridge` | ✅ | Clear entire fridge |

### Recipes
| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| GET | `/api/recipes` | ✅ | List recipes (`?saved=true`) |
| GET | `/api/recipes/:id` | ✅ | Get one recipe |
| POST | `/api/recipes` | ✅ | Save new recipe |
| PATCH | `/api/recipes/:id/save` | ✅ | Toggle saved |
| DELETE | `/api/recipes/:id` | ✅ | Delete recipe |

### User
| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| GET | `/api/user/me` | ✅ | Get profile |
| PUT | `/api/user/me` | ✅ | Update profile |
| PUT | `/api/user/change-password` | ✅ | Change password |
| DELETE | `/api/user/me` | ✅ | Delete account |

---

## MongoDB Atlas Setup

1. Sign up at [cloud.mongodb.com](https://cloud.mongodb.com)
2. Create a free **M0** cluster → region: Mumbai
3. Add DB user (username + password)
4. Allow all IPs: `0.0.0.0/0` (dev) or your server IP (prod)
5. Copy the connection string to `.env` as `MONGO_URI`

---

## Flutter Integration

Add to Flutter `pubspec.yaml`:
```yaml
dependencies:
  http: ^1.2.0
  shared_preferences: ^2.2.3
```

Base URLs:
- Android emulator: `http://10.0.2.2:3000/api`
- iOS simulator: `http://127.0.0.1:3000/api`
- Physical device: `http://<your-pc-local-ip>:3000/api`
- Production: `https://your-app.onrender.com/api`

---

## Deployment (Render.com — Free)

1. Push to GitHub
2. New Web Service → connect repo
3. Build command: `npm install`
4. Start command: `node server.js`
5. Add env vars: `MONGO_URI`, `JWT_SECRET`, `NODE_ENV=production`
