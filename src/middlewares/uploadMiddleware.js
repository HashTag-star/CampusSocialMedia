const multer = require('multer');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const supabase = require('../config/supabase');
const sharp = require('sharp');

// ── Image Processing Presets (Instagram-style) ──
const IMAGE_PRESETS = {
    feed: { maxWidth: 1080, maxHeight: 1350, quality: 82 },
    story: { maxWidth: 1080, maxHeight: 1920, quality: 80 },
    avatar: { maxWidth: 400, maxHeight: 400, quality: 85 },
};

/**
 * Process an image buffer with sharp:
 * - Auto-orient (fix rotation from EXIF)
 * - Resize to fit within max dimensions (preserving aspect ratio)
 * - Convert to progressive JPEG at specified quality
 * - Strip all EXIF/metadata
 */
async function processImage(buffer, preset = 'feed') {
    const config = IMAGE_PRESETS[preset] || IMAGE_PRESETS.feed;

    try {
        const processed = await sharp(buffer)
            .rotate()                           // Auto-orient based on EXIF
            .resize(config.maxWidth, config.maxHeight, {
                fit: 'inside',                  // Preserve aspect ratio, fit within bounds
                withoutEnlargement: true,        // Don't upscale small images
            })
            .jpeg({
                quality: config.quality,
                progressive: true,              // Progressive JPEG for faster perceived loading
                mozjpeg: true,                   // Use MozJPEG encoder for better compression
            })
            .toBuffer();

        return { buffer: processed, mimetype: 'image/jpeg', ext: '.jpg' };
    } catch (err) {
        console.warn('⚠️ Image processing failed, using original:', err.message);
        return null; // Fallback to original
    }
}

// Use Memory Storage to get accessible file buffer
const storage = multer.memoryStorage();

const fileFilter = (req, file, cb) => {
    if (file.mimetype.startsWith('image/') || file.mimetype.startsWith('video/') || file.mimetype.startsWith('audio/')) {
        cb(null, true);
    } else {
        cb(new Error('Only images, videos, and audio are allowed!'), false);
    }
};

const upload = multer({ 
    storage: storage,
    fileFilter: fileFilter,
    limits: { fileSize: 50 * 1024 * 1024 } // 50MB limit per file
});

// Helper: upload a single buffer to Supabase
async function uploadFileToSupabase(file, preset = 'feed') {
    let fileBuffer = file.buffer;
    let fileMimetype = file.mimetype;
    let fileExt = path.extname(file.originalname);

    // Process images through sharp (skip videos/audio)
    if (file.mimetype.startsWith('image/')) {
        const processed = await processImage(fileBuffer, preset);
        if (processed) {
            fileBuffer = processed.buffer;
            fileMimetype = processed.mimetype;
            fileExt = processed.ext;
        }
    }

    const fileName = `${uuidv4()}${fileExt}`;
    const filePath = `uploads/${fileName}`;

    let { data, error } = await supabase.storage
        .from('campus-media')
        .upload(filePath, fileBuffer, {
            contentType: fileMimetype,
            upsert: false
        });

    // Auto-Fix: Create bucket if missing
    if (error && (error.statusCode === '404' || error.message.includes('Bucket not found'))) {
        console.log('🪣 Bucket not found. Attempting to create "campus-media"...');
        const { error: createError } = await supabase.storage.createBucket('campus-media', { public: true });
        
        if (createError) {
            console.error('❌ Failed to automatically create bucket:', createError.message);
            throw new Error('Supabase Bucket "campus-media" missing. Please create it in your Supabase Dashboard -> Storage.');
        }
        
        console.log('✅ Bucket "campus-media" created. Retrying upload...');
        const retry = await supabase.storage
            .from('campus-media')
            .upload(filePath, fileBuffer, {
                contentType: fileMimetype,
                upsert: false
            });
        
        data = retry.data;
        error = retry.error;
    }

    if (error) throw error;

    const { data: publicData } = supabase.storage
        .from('campus-media')
        .getPublicUrl(filePath);

    return publicData.publicUrl;
}

// Single-file upload middleware (for stories, avatars, etc.)
const uploadToSupabase = async (req, res, next) => {
    if (!req.file) return next();

    // Detect preset from route path
    let preset = 'feed';
    if (req.originalUrl.includes('avatar')) preset = 'avatar';
    else if (req.originalUrl.includes('stor')) preset = 'story';

    try {
        const url = await uploadFileToSupabase(req.file, preset);
        req.file.path = url;
        next();
    } catch (error) {
        console.error('Supabase Upload Error:', error);
        return res.status(500).json({ message: 'Media upload failed' });
    }
};

// Multi-file upload middleware (for carousel posts)
const uploadMultipleToSupabase = async (req, res, next) => {
    if (!req.files || req.files.length === 0) return next();

    try {
        const urls = [];
        for (const file of req.files) {
            const url = await uploadFileToSupabase(file);
            urls.push(url);
        }
        // Attach all URLs to request for the controller
        req.uploadedUrls = urls;
        // Also set first file info for backwards compatibility
        req.files[0].path = urls[0];
        next();
    } catch (error) {
        console.error('Supabase Multi Upload Error:', error);
        return res.status(500).json({ message: 'Media upload failed' });
    }
};

module.exports = { upload, uploadToSupabase, uploadMultipleToSupabase };
