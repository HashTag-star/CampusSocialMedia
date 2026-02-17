const express = require('express');
const router = express.Router();
const storyController = require('../controllers/storyController');
const { upload, uploadToSupabase } = require('../middlewares/uploadMiddleware');
const auth = require('../middlewares/authMiddleware');

// Create Story (with media upload)
router.post('/', auth, upload.single('file'), uploadToSupabase, storyController.createStory);

// Get All Active Stories (grouped by user)
router.get('/', auth, storyController.getStories);

// Get Stories for a specific user
router.get('/:userId', auth, storyController.getUserStories);

// Story Interactions
router.post('/:id/view', auth, storyController.viewStory);
router.post('/:id/interact', auth, storyController.interactStory);
router.get('/:id/viewers', auth, storyController.getStoryViewers);

module.exports = router;
