const express = require('express');
const router = express.Router();
const courseController = require('../controllers/courseController');
const auth = require('../middlewares/authMiddleware');

router.get('/', auth, courseController.listCourses);
router.get('/my', auth, courseController.getMyCourses);
router.post('/:courseId/join', auth, courseController.joinCourse);

module.exports = router;
