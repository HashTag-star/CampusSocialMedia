const { sequelize, User, Post, University, Follow, Block } = require('../models');

// Block a User
exports.blockUser = async (req, res) => {
    try {
        const blockerId = req.user.id;
        const { userId: blockedId } = req.params;

        if (blockerId === blockedId) {
            return res.status(400).json({ message: 'You cannot block yourself' });
        }

        // 1. Create Block Record
        await Block.findOrCreate({
            where: { blocker_id: blockerId, blocked_id: blockedId }
        });

        // 2. Remove Follows (Both directions)
        await Follow.destroy({
            where: {
                [require('sequelize').Op.or]: [
                    { follower_id: blockerId, following_id: blockedId },
                    { follower_id: blockedId, following_id: blockerId }
                ]
            }
        });

        res.json({ message: 'User blocked successfully' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Unblock a User
exports.unblockUser = async (req, res) => {
    try {
        const blockerId = req.user.id;
        const { userId: blockedId } = req.params;

        const deleted = await Block.destroy({
            where: { blocker_id: blockerId, blocked_id: blockedId }
        });

        if (!deleted) {
            return res.status(404).json({ message: 'Block not found' });
        }

        res.json({ message: 'User unblocked successfully' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Get My Profile (with Posts + Stats)
exports.getMe = async (req, res) => {
    try {
        const user = await User.findByPk(req.user.id, {
            attributes: { exclude: ['password_hash'] },
            include: [
                { model: University, attributes: ['name', 'domain'] },
                { model: Post, limit: 30, order: [['createdAt', 'DESC']] }
            ]
        });

        if (!user) return res.status(404).json({ message: 'User not found' });

        const followersCount = await Follow.count({ where: { following_id: req.user.id } });
        const followingCount = await Follow.count({ where: { follower_id: req.user.id } });

        res.json({
            ...user.toJSON(),
            followersCount,
            followingCount,
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Update Profile (e.g., interests, bio)
exports.updateProfile = async (req, res) => {
    try {
        const { name, bio, major, year, interests } = req.body;
        const user = await User.findByPk(req.user.id);

        if (!user) return res.status(404).json({ message: 'User not found' });

        // Update profile_data JSONB
        const updatedProfileData = {
            ...user.profile_data,
            name: name || user.profile_data.name,
            bio: bio || user.profile_data.bio,
            major: major || user.profile_data.major,
            year: year || user.profile_data.year,
            interests: interests || user.profile_data.interests
        };

        user.profile_data = updatedProfileData;
        await user.save();

        res.json(user);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Upload / Update Avatar
exports.updateAvatar = async (req, res) => {
    try {
        if (!req.file) return res.status(400).json({ message: 'No file uploaded' });

        const user = await User.findByPk(req.user.id);
        if (!user) return res.status(404).json({ message: 'User not found' });

        // req.file.path is set by uploadToSupabase middleware to the public URL
        const avatarUrl = req.file.path;

        user.profile_data = {
            ...user.profile_data,
            avatar_url: avatarUrl,
        };
        await user.save();

        res.json({ ...user.toJSON(), avatar_url: avatarUrl });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Get User Profile by ID (with Stats)
exports.getUserProfile = async (req, res) => {
    try {
        const userId = req.params.id;
        const currentUserId = req.user.id;

        // 0. Check for Block
        const { Op } = require('sequelize');
        const block = await Block.findOne({
            where: {
                [Op.or]: [
                    { blocker_id: currentUserId, blocked_id: userId },
                    { blocker_id: userId, blocked_id: currentUserId }
                ]
            }
        });

        if (block) {
            return res.status(404).json({ message: 'User not found' }); // Hide existence
        }

        const user = await User.findByPk(userId, {
            attributes: { exclude: ['password_hash'] },
            include: [
                { model: University, attributes: ['name'] },
                { 
                    model: Post, 
                    limit: 20, 
                    order: [['createdAt', 'DESC']]
                }
            ]
        });

        if (!user) return res.status(404).json({ message: 'User not found' });

        // Get Follow Stats
        const followersCount = await user.countFollowers();
        const followingCount = await user.countFollowing();
        
        // Check if I am following this user
        const isFollowing = await user.hasFollower(currentUserId);

        res.json({
            ...user.toJSON(),
            followersCount,
            followingCount,
            isFollowing
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Get Users with active stories (posted in last 24h)
exports.getUsersWithStories = async (req, res) => {
    try {
        const oneDayAgo = new Date(new Date() - 24 * 60 * 60 * 1000);
        
        const users = await User.findAll({
            attributes: ['id', 'email', 'profile_data'],
            include: [{
                model: Post,
                attributes: [],
                where: {
                    createdAt: {
                        [require('sequelize').Op.gte]: oneDayAgo
                    }
                },
                required: true // Only users with posts
            }],
            group: ['User.id'], // Unique users
            limit: 10
        });

        res.json(users);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Search Users by name or email
exports.searchUsers = async (req, res) => {
    try {
        const { q } = req.query;
        if (!q) return res.json([]);

        const { Op } = require('sequelize');
        const currentUserId = req.user.id;

        // 0. Get Block Lists
        const blocks = await Block.findAll({
            where: {
                [Op.or]: [
                    { blocker_id: currentUserId },
                    { blocked_id: currentUserId }
                ]
            }
        });
        const blockedUserIds = blocks.map(b => b.blocker_id === currentUserId ? b.blocked_id : b.blocker_id);

        const users = await User.findAll({
            where: {
                id: { [Op.notIn]: [...blockedUserIds, currentUserId] }, // Exclude blocked + self
                [Op.or]: [
                    { email: { [Op.iLike]: `%${q}%` } },
                    require('sequelize').where(
                        require('sequelize').cast(
                            require('sequelize').col('profile_data'),
                            'text'
                        ),
                        { [Op.iLike]: `%${q}%` }
                    ),
                ]
            },
            attributes: { exclude: ['password_hash'] },
            include: [{ model: University, attributes: ['name'] }],
            limit: 15,
        });

        res.json(users);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};
// Get Suggested Users to Follow (Friends of Friends)
exports.getSuggestedUsers = async (req, res) => {
    try {
        const userId = req.user.id;
        const user = await User.findByPk(userId);
        
        if (!user) return res.status(404).json({ message: 'User not found' });

        const { Op } = require('sequelize');

        // 1. Get IDs of users I already follow
        const following = await Follow.findAll({ 
            where: { follower_id: userId },
            attributes: ['following_id']
        });
        const followingIds = following.map(f => f.following_id);
        followingIds.push(userId); // Exclude self

        // 2. Find Friends of Friends (only if user follows anyone)
        let suggestions = [];
        
        if (followingIds.length > 1) { // > 1 because we pushed self
            const friendsOfFriends = await Follow.findAll({
                where: {
                    follower_id: { [Op.in]: followingIds },
                    following_id: { [Op.notIn]: followingIds }
                },
                attributes: ['following_id', [sequelize.fn('COUNT', sequelize.col('following_id')), 'mutuals']],
                group: ['following_id'],
                order: [[sequelize.literal('mutuals'), 'DESC']],
                limit: 20
            });

            const fofIds = friendsOfFriends.map(f => f.following_id);

            // 3. Fetch these 2nd degree users
            if (fofIds.length > 0) {
                const fofUsers = await User.findAll({
                    where: { id: { [Op.in]: fofIds } },
                    attributes: ['id', 'email', 'profile_data']
                });
                suggestions = [...fofUsers];
            }
        }

        // 4. Fill remaining spots with random uni users
        if (suggestions.length < 10) {
            const excludeIds = [...followingIds, ...suggestions.map(s => s.id)];
            const whereClause = {
                id: { [Op.notIn]: excludeIds }
            };
            // Only filter by university if user has one
            if (user.university_id) {
                whereClause.university_id = user.university_id;
            }
            const extra = await User.findAll({
                where: whereClause,
                attributes: ['id', 'email', 'profile_data'],
                limit: 10 - suggestions.length,
                order: sequelize.random()
            });
            suggestions = [...suggestions, ...extra];
        }

        res.json(suggestions);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};
