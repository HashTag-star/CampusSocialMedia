const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const authMiddleware = require('../middlewares/authMiddleware');
const adminMiddleware = require('../middlewares/adminMiddleware');

// Check Role Middleware Stack: Auth -> Admin
const protect = [authMiddleware, adminMiddleware];

// Get Reports
router.get('/reports', protect, adminController.getReports);

// Managed Reports
router.put('/reports/:id/status', protect, adminController.updateReportStatus);

// Ban User
router.post('/users/:id/ban', protect, adminController.banUser);

module.exports = router;
