const express = require('express');
const router = express.Router();
const interactionController = require('../controllers/interactionController');
const auth = require('../middlewares/authMiddleware');

// Toggle Like on Comment
router.post('/:commentId/like', auth, interactionController.toggleCommentLike);

module.exports = router;

