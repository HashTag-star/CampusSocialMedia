const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const followController = require('../controllers/followController'); // Re-using follow controller logic here or keeping separate?
const auth = require('../middlewares/authMiddleware');
const { upload, uploadToSupabase } = require('../middlewares/uploadMiddleware');

router.get('/me', auth, userController.getMe);
router.get('/stories', auth, userController.getUsersWithStories);
router.patch('/me', auth, userController.updateProfile);
router.patch('/me/avatar', auth, upload.single('file'), uploadToSupabase, userController.updateAvatar);
router.get('/search', auth, userController.searchUsers);
router.get('/suggestions/list', auth, userController.getSuggestedUsers);

// Block / Unblock
router.post('/:userId/block', auth, userController.blockUser);
router.delete('/:userId/block', auth, userController.unblockUser);

router.get('/:id', auth, userController.getUserProfile);

// Follow Routes (Moving here from server.js to be cleaner, but keeping separate based on previous file structure)
// We already have /api/users pointing to followRoutes in server.js, 
// so we should probably merge them or just mount this as /api/profile?
// Let's keep it consistent: server.js mounts this as /api/users

// Merge with follow routes which are also users related
router.post('/:userId/follow', auth, followController.followUser);
router.delete('/:userId/unfollow', auth, followController.unfollowUser);
router.get('/:userId/followers', auth, followController.getFollowers);
router.get('/:userId/following', auth, followController.getFollowing);

module.exports = router;
