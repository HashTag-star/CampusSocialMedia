const express = require('express');
const router = express.Router();
const eventController = require('../controllers/eventController');
const auth = require('../middlewares/authMiddleware');

router.post('/', auth, eventController.createEvent);
router.get('/', auth, eventController.listEvents);
router.post('/:eventId/rsvp', auth, eventController.rsvpEvent);

module.exports = router;
