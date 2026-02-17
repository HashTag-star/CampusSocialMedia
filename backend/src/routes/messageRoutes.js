const express = require('express');
const router = express.Router();
const messageController = require('../controllers/messageController');
const auth = require('../middlewares/authMiddleware');

router.get('/conversations', auth, messageController.getConversations);
router.post('/conversations', auth, messageController.createConversation);
router.get('/conversations/:id/messages', auth, messageController.getMessages);
router.post('/conversations/:id/messages', auth, messageController.sendMessage);
router.patch('/conversations/:id/read', auth, messageController.markAsRead);
router.post('/upload', auth, require('../middlewares/uploadMiddleware').upload.single('file'), require('../middlewares/uploadMiddleware').uploadToSupabase, messageController.uploadMedia);

module.exports = router;
