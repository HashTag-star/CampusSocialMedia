const { User, Story, University, StoryView, sequelize } = require('../models');
const { Op } = require('sequelize');

// Create a Story
exports.createStory = async (req, res) => {
    try {
        const userId = req.user.id;
        const user = await User.findByPk(userId);

        if (!user) return res.status(404).json({ message: 'User not found' });

        const mediaUrl = req.file?.path;
        if (!mediaUrl) return res.status(400).json({ message: 'Media is required for a story' });

        const mediaType = req.file.mimetype.startsWith('video/') ? 'video' : 'image';

        const story = await Story.create({
            user_id: userId,
            university_id: user.university_id,
            media_url: mediaUrl,
            media_type: mediaType,
            caption: req.body.caption || null,
            expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000) // 24 hours from now
        });

        res.status(201).json(story);
    } catch (error) {
        console.error('Error creating story:', error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Get Active Stories (grouped by user)
exports.getStories = async (req, res) => {
    try {
        const userId = req.user.id;
        const now = new Date();

        const stories = await Story.findAll({
            where: {
                expires_at: { [Op.gt]: now }
            },
            include: [
                {
                    model: User,
                    attributes: ['id', 'email', 'profile_data']
                },
                {
                    model: StoryView,
                    required: false,
                    where: { viewer_id: userId },
                    attributes: ['id', 'createdAt'] // Just need existence
                }
            ],
            order: [['createdAt', 'DESC']]
        });

        // Group stories by user
        const grouped = {};
        for (const story of stories) {
            const uid = story.user_id;
            if (!grouped[uid]) {
                grouped[uid] = {
                    user: story.User,
                    stories: []
                };
            }
            
            const isSeen = story.StoryViews && story.StoryViews.length > 0;

            grouped[uid].stories.push({
                id: story.id,
                media_url: story.media_url,
                media_type: story.media_type,
                caption: story.caption,
                created_at: story.createdAt,
                expires_at: story.expires_at,
                is_seen: isSeen
            });
        }

        res.json(Object.values(grouped));
    } catch (error) {
        console.error('Error fetching stories:', error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Get stories for a specific user
exports.getUserStories = async (req, res) => {
    try {
        const userId = req.params.userId;
        const currentUserId = req.user.id;
        const now = new Date();

        const stories = await Story.findAll({
            where: {
                user_id: userId,
                expires_at: { [Op.gt]: now }
            },
            include: [{
                model: StoryView,
                required: false,
                where: { viewer_id: currentUserId }
            }],
            order: [['createdAt', 'ASC']]
        });

        const result = stories.map(s => {
            const json = s.toJSON();
            json.is_seen = s.StoryViews && s.StoryViews.length > 0;
            // Add view count for owner
            return json;
        });

        res.json(result);
    } catch (error) {
        console.error('Error fetching user stories:', error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Record a view
exports.viewStory = async (req, res) => {
    try {
        const { id } = req.params;
        const viewerId = req.user.id;

        const story = await Story.findByPk(id);
        if (!story) return res.status(404).json({ message: 'Story not found' });

        // Don't record view if own story (optional, but usually we count others)
        if (story.user_id === viewerId) return res.json({ message: 'Own story' });

        await StoryView.findOrCreate({
            where: { story_id: id, viewer_id: viewerId }
        });

        res.json({ message: 'View recorded' });
    } catch (error) {
        console.error('Error recording view:', error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Interact (Like, React, Reply)
exports.interactStory = async (req, res) => {
    try {
        const { id } = req.params;
        const viewerId = req.user.id;
        const { liked, reaction, reply } = req.body;

        const story = await Story.findByPk(id);
        if (!story) return res.status(404).json({ message: 'Story not found' });

        const [view, created] = await StoryView.findOrCreate({
            where: { story_id: id, viewer_id: viewerId }
        });

        if (liked !== undefined) view.liked = liked;
        if (reaction !== undefined) view.reaction = reaction;
        if (reply !== undefined) view.reply = reply; // In real app, might want to send DM too

        await view.save();

        res.json(view);
    } catch (error) {
        console.error('Error interacting with story:', error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Get Story Viewers (for owner)
exports.getStoryViewers = async (req, res) => {
    try {
        const { id } = req.params;
        const userId = req.user.id;

        const story = await Story.findByPk(id);
        if (!story) return res.status(404).json({ message: 'Story not found' });

        if (story.user_id !== userId) {
            return res.status(403).json({ message: 'Unauthorized' });
        }

        const views = await StoryView.findAll({
            where: { story_id: id },
            include: [{
                model: User,
                as: 'viewer',
                attributes: ['id', 'email', 'profile_data']
            }],
            order: [['updatedAt', 'DESC']]
        });

        res.json(views);
    } catch (error) {
        console.error('Error fetching story viewers:', error);
        res.status(500).json({ message: 'Server error' });
    }
};
