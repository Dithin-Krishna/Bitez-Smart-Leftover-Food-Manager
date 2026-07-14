const cloudinary = require('cloudinary').v2;
const multer     = require('multer');

// Configure Cloudinary from env vars
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key:    process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

// Use memory storage so the buffer can be streamed directly to Cloudinary
const storage = multer.memoryStorage();

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },  // 10 MB max
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'), false);
    }
  },
});

/**
 * uploadToCloudinary — uploads a buffer directly to Cloudinary.
 * @param {Buffer} buffer   - File buffer from multer
 * @param {string} folder   - Cloudinary folder (e.g. 'bitez/food-photos')
 * @returns {Promise<string>} Secure URL of the uploaded image
 */
const uploadToCloudinary = (buffer, folder = 'bitez/food-photos') =>
  new Promise((resolve, reject) => {
    const stream = cloudinary.uploader.upload_stream(
      { folder, resource_type: 'image', quality: 'auto' },
      (error, result) => {
        if (error) return reject(error);
        resolve(result.secure_url);
      }
    );
    stream.end(buffer);
  });

module.exports = { upload, uploadToCloudinary };
