const { Space, User } = require('../models');
const jwt = require('jsonwebtoken'); // Using standard JWT for mock token

// Create Space
exports.createSpace = async (req, res) => {
    try {
        const userId = req.user.id;
        const { title, topic } = req.body;
        
        const user = await User.findByPk(userId);
        if (!user.university_id) return res.status(400).json({ message: 'User not affiliated with university' });

        const newSpace = await Space.create({
            host_id: userId,
            university_id: user.university_id,
            title,
            topic,
            is_active: true
        });

        res.status(201).json(newSpace);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// List Active Spaces
exports.listSpaces = async (req, res) => {
    try {
        const userId = req.user.id;
        const user = await User.findByPk(userId);

        const spaces = await Space.findAll({
            where: { 
                university_id: user.university_id,
                is_active: true 
            },
            include: [{ model: User, as: 'Host', attributes: ['id', 'email', 'profile_data'] }],
            order: [['createdAt', 'DESC']]
        });

        res.json(spaces);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Join Space (Get Token)
exports.joinSpace = async (req, res) => {
    try {
        const userId = req.user.id;
        const spaceId = req.params.spaceId;
        const user = await User.findByPk(userId);

        const space = await Space.findByPk(spaceId);
        if (!space || !space.is_active) {
            return res.status(404).json({ message: 'Space not found or inactive' });
        }

        // --- MOCK SFU TOKEN GENERATION ---
        // In production, this would use the LiveKit/Agora SDK to generate a token
        // for the specific room. Here we mock it with a simple JWT.
        const mockSfuToken = jwt.sign(
            { 
                sub: userId,
                name: user.email, 
                room: spaceId,
                role: space.host_id === userId ? 'moderator' : 'subscriber'
            },
            process.env.JWT_SECRET || 'secret',
            { expiresIn: '1h' }
        );

        res.json({ 
            token: mockSfuToken,
            space,
            connection_details: {
                server_url: "wss://mock-sfu.university-social.com",
                room_name: spaceId
            }
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// End Space
exports.endSpace = async (req, res) => {
    try {
        const userId = req.user.id;
        const spaceId = req.params.spaceId;

        const space = await Space.findByPk(spaceId);
        if (!space) return res.status(404).json({ message: 'Space not found' });

        if (space.host_id !== userId) {
            return res.status(403).json({ message: 'Only host can end space' });
        }

        space.is_active = false;
        await space.save();

        res.json({ message: 'Space ended' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};
