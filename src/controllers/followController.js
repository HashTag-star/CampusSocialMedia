const { User, Follow } = require('../models');

// Follow User
exports.followUser = async (req, res) => {
    try {
        const followerId = req.user.id;
        const followingId = req.params.userId;

        if (followerId === followingId) {
            return res.status(400).json({ message: 'Cannot follow yourself' });
        }

        const userToFollow = await User.findByPk(followingId);
        if (!userToFollow) {
            return res.status(404).json({ message: 'User not found' });
        }

        const [follow, created] = await Follow.findOrCreate({
            where: {
                follower_id: followerId,
                following_id: followingId
            }
        });

        if (!created) {
            return res.status(400).json({ message: 'Already following this user' });
        }

        res.status(200).json({ message: 'Followed successfully' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Unfollow User
exports.unfollowUser = async (req, res) => {
    try {
        const followerId = req.user.id;
        const followingId = req.params.userId;

        const follow = await Follow.findOne({
            where: {
                follower_id: followerId,
                following_id: followingId
            }
        });

        if (!follow) {
            return res.status(400).json({ message: 'Not following this user' });
        }

        await follow.destroy();
        res.status(200).json({ message: 'Unfollowed successfully' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Get Followers
exports.getFollowers = async (req, res) => {
    try {
        const userId = req.params.userId;
        const user = await User.findByPk(userId, {
            include: [{ model: User, as: 'Followers', attributes: ['id', 'email', 'profile_data'] }]
        });

        if (!user) return res.status(404).json({ message: 'User not found' });

        res.json(user.Followers);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Get Following
exports.getFollowing = async (req, res) => {
    try {
        const userId = req.params.userId;
        const user = await User.findByPk(userId, {
            include: [{ model: User, as: 'Following', attributes: ['id', 'email', 'profile_data'] }]
        });

        if (!user) return res.status(404).json({ message: 'User not found' });

        res.json(user.Following);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};
