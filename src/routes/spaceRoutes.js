const express = require('express');
const router = express.Router();
const spaceController = require('../controllers/spaceController');
const auth = require('../middlewares/authMiddleware');

router.post('/', auth, spaceController.createSpace);
router.get('/', auth, spaceController.listSpaces);
router.post('/:spaceId/join', auth, spaceController.joinSpace);
router.post('/:spaceId/end', auth, spaceController.endSpace);

module.exports = router;
