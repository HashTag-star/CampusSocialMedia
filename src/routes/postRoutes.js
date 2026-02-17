const express = require('express');
const router = express.Router();
const postController = require('../controllers/postController');
const { upload, uploadMultipleToSupabase } = require('../middlewares/uploadMiddleware');
const auth = require('../middlewares/authMiddleware');

const interactionController = require('../controllers/interactionController');

// Create Post (multer handles 'files' field — up to 10 files)
router.post('/', auth, upload.array('files', 10), uploadMultipleToSupabase, postController.createPost);

// Get Campus Feed
router.get('/feed/campus', auth, postController.getCampusFeed);
router.get('/feed/home', auth, postController.getHomeFeed);
router.get('/feed/foryou', auth, postController.getForYouFeed);
router.get('/search', auth, postController.searchPosts);
router.get('/shorts', auth, postController.getShorts);

// Interactions
router.post('/:postId/like', auth, interactionController.toggleLike);
router.post('/:postId/comments', auth, interactionController.addComment);
router.get('/:postId/comments', auth, interactionController.getComments);
router.post('/:postId/view', auth, interactionController.recordPostView); // [NEW]

// Single Post CRUD
router.get('/:postId', auth, postController.getPostById);
router.patch('/:postId', auth, postController.updatePost);
router.delete('/:postId', auth, postController.deletePost);

module.exports = router;
