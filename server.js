import dotenv from 'dotenv';
dotenv.config();
import express from 'express';
import mongoose from 'mongoose';
import cors from 'cors';
import bcrypt from 'bcryptjs';

const app = express();

app.use(express.json());
app.use(cors());

// Define User Schema & Model FIRST before seedAdmins uses it
const userSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: { type: String },
  role: { type: String, default: 'admin' },
  avatarUrl: String,
  avatar: String,
  age: Number,
  gender: String,
  phone: String,
  status: { type: String, default: 'online' },
}, { timestamps: true, strict: false });

const User = mongoose.model('User', userSchema, 'users');

// Auto-seed admin function
async function seedAdmins() {
  const ADMINS = [
    {
      name: 'Bhadra',
      email: 'bhadra050127@gmail.com',
      rawPassword: 'Bhadra@123',
    },
    {
      name: 'Dithin',
      email: 'dithinkrishna45@gmail.com',
      rawPassword: 'dithin@123',
    },
  ];

  try {
    for (const admin of ADMINS) {
      const normalizedEmail = admin.email.toLowerCase();
      const salt = await bcrypt.genSalt(10);
      const hashedPassword = await bcrypt.hash(admin.rawPassword, salt);

      const result = await User.findOneAndUpdate(
        { email: normalizedEmail },
        {
          $setOnInsert: {
            name: admin.name,
            email: normalizedEmail,
            password: hashedPassword,
            role: 'admin',
            status: 'online',
          },
        },
        { upsert: true, new: true }
      );

      console.log(`👤 Admin verified/created in test.users: ${result.email}`);
    }
  } catch (err) {
    console.error('❌ Error during seedAdmins:', err.message);
  }
}

// Connect to MongoDB Atlas
const MONGO_URI = process.env.MONGO_URI || '';

mongoose
  .connect(MONGO_URI, { dbName: 'test' })
  .then(async () => {
    console.log('✅ Connected to MongoDB Atlas successfully (Target Database: test)');
    await seedAdmins();
  })
  .catch((err) => console.error('❌ MongoDB connection error:', err));
  