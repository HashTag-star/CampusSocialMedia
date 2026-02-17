const express = require('express');
const router = express.Router();
const interactionController = require('../controllers/interactionController');
const authMiddleware = require('../middlewares/authMiddleware');

// Report Content
router.post('/report', authMiddleware, interactionController.reportContent);

module.exports = router;
