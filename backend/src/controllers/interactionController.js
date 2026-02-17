const { Post, Like, Comment, CommentLike, User, Notification, Report, PostView, Block } = require('../models');

// Report Content (Post, Comment, User, Story)
exports.reportContent = async (req, res) => {
    try {
        const reporterId = req.user.id;
        const { targetType, targetId, reason, description } = req.body;

        if (!['post', 'comment', 'user', 'story'].includes(targetType)) {
            return res.status(400).json({ message: 'Invalid target type' });
        }

        await Report.create({
            reporter_id: reporterId,
            target_type: targetType,
            target_id: targetId,
            reason,
            description,
            status: 'pending'
        });

        res.status(201).json({ message: 'Report submitted successfully' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Helper to update user interests
const updateUserInterests = async (user, tags, weight) => {
    if (!tags || tags.length === 0) return;
    
    // Ensure interests object exists
    const interests = user.interests ? { ...user.interests } : {};
    
    tags.forEach(tag => {
        interests[tag] = (interests[tag] || 0) + weight;
    });
    
    // Update user
    await user.update({ interests });
};

// Toggle Like
exports.toggleLike = async (req, res) => {
    try {
        const userId = req.user.id;
        const postId = req.params.postId;

        const post = await Post.findByPk(postId);
        if (!post) return res.status(404).json({ message: 'Post not found' });

        const existingLike = await Like.findOne({
            where: { user_id: userId, post_id: postId }
        });

        if (existingLike) {
            await existingLike.destroy();
            return res.json({ message: 'Post unliked', liked: false });
        } else {
            await Like.create({ user_id: userId, post_id: postId });

            // TRACKING: Update User Interests (+1 for Like)
            const user = await User.findByPk(userId);
            if (user && post.tags) {
                await updateUserInterests(user, post.tags, 1);
            }

            // Create Notification
            if (post.user_id !== userId) {
                await Notification.create({
                    recipient_id: post.user_id,
                    actor_id: userId,
                    type: 'like',
                    entity_id: postId,
                    entity_type: 'post',
                    message: 'liked your post'
                });
            }

            return res.json({ message: 'Post liked', liked: true });
        }
    } catch (error) {
        console.error('💥 Error in toggleLike:', error);
        res.status(500).json({ message: 'Server error' });
    }
};

const moderationService = require('../services/moderationService');

// Add Comment (supports threading via parentId)
exports.addComment = async (req, res) => {
    try {
        const userId = req.user.id;
        const postId = req.params.postId;
        const { content, parentId } = req.body;

        if (!content) return res.status(400).json({ message: 'Comment content is required' });

        // --- MODERATION CHECK ---
        const modResult = moderationService.analyzeText(content);
        if (modResult.action === 'block') {
            return res.status(400).json({ message: modResult.reason });
        }
        const isSensitive = modResult.action === 'flag';
        // ------------------------

        const post = await Post.findByPk(postId);
        if (!post) return res.status(404).json({ message: 'Post not found' });

        // If parentId is provided, verify it exists and belongs to the same post
        if (parentId) {
            const parentComment = await Comment.findByPk(parentId);
            if (!parentComment) return res.status(404).json({ message: 'Parent comment not found' });
            if (parentComment.post_id !== postId) return res.status(400).json({ message: 'Parent comment belongs to a different post' });
        }

        const comment = await Comment.create({
            user_id: userId,
            post_id: postId,
            parent_id: parentId || null,
            content,
            is_sensitive: isSensitive
        });

        const commentWithUser = await Comment.findByPk(comment.id, {
            include: [{ model: User, attributes: ['id', 'email', 'profile_data'] }]
        });
        
        // Add minimal fields to match getComments structure
        const result = commentWithUser.toJSON();
        result.likesCount = 0;
        result.isLikedByMe = false;
        result.Replies = [];

        res.status(201).json(result);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Get Comments for a Post (Nested)
exports.getComments = async (req, res) => {
    try {
        const postId = req.params.postId;
        const currentUserId = req.user.id;

        // 0. Get Block List
        const { Op } = require('sequelize');
        const Block = require('../models').Block;
        
        const blocks = await Block.findAll({
            where: {
                [Op.or]: [
                    { blocker_id: currentUserId },
                    { blocked_id: currentUserId }
                ]
            }
        });
        const blockedUserIds = blocks.map(b => b.blocker_id === currentUserId ? b.blocked_id : b.blocker_id);

        // Fetch all comments for the post (excluding blocked users)
        const comments = await Comment.findAll({
            where: { 
                post_id: postId,
                user_id: { [Op.notIn]: blockedUserIds } // Safety Filter
            },
            include: [
                { model: User, attributes: ['id', 'email', 'profile_data'] },
                { model: CommentLike } // Include likes to count them
            ],
            order: [['createdAt', 'ASC']]
        });

        // Process comments to add interactions and nesting
        const commentMap = {};
        const rootComments = [];

        // First pass: Format comments and add helper fields
        for (const c of comments) {
            const json = c.toJSON();
            json.likesCount = c.CommentLikes.length;
            json.isLikedByMe = c.CommentLikes.some(like => like.user_id === currentUserId);
            delete json.CommentLikes; // Clean up
            json.Replies = [];
            
            commentMap[json.id] = json;
        }

        // Second pass: Build hierarchy
        for (const id in commentMap) {
            const comment = commentMap[id];
            if (comment.parent_id) {
                if (commentMap[comment.parent_id]) {
                    commentMap[comment.parent_id].Replies.push(comment);
                }
            } else {
                rootComments.push(comment);
            }
        }

        res.json(rootComments);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Toggle Comment Like
exports.toggleCommentLike = async (req, res) => {
    try {
        const userId = req.user.id;
        const commentId = req.params.commentId;

        const comment = await Comment.findByPk(commentId);
        if (!comment) return res.status(404).json({ message: 'Comment not found' });

        const existingLike = await CommentLike.findOne({
            where: { user_id: userId, comment_id: commentId }
        });

        if (existingLike) {
            await existingLike.destroy();
            return res.json({ message: 'Comment unliked', liked: false });
        } else {
            await CommentLike.create({ user_id: userId, comment_id: commentId });
            return res.json({ message: 'Comment liked', liked: true });
        }
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Record Post View (Implicit Feedback)
exports.recordPostView = async (req, res) => {
    try {
        const userId = req.user.id;
        const postId = req.params.postId;
        const { timeSpentMs } = req.body; // Optional: time spent in ms

        // 1. Log the view
        // Use findOrCreate to avoid spamming views if the user scrolls past multiple times in short session
        // In a real big-data system, this would be a high-throughput event stream (Kafka/Kinesis)
        // For MVP, Postgres is fine.
        const [view, created] = await PostView.findOrCreate({
            where: { 
                viewer_id: userId, 
                post_id: postId,
                // Simple de-duping: One view per day per post? Or just one per session? 
                // Let's just create raw views for now, but usually we'd limit by time window.
                createdAt: { [require('sequelize').Op.gte]: new Date(Date.now() - 10 * 60 * 1000) } // 10 min throttle
            },
            defaults: {
                viewer_id: userId,
                post_id: postId,
                viewer_id: userId, // Fix for association alias if needed
                time_spent_ms: timeSpentMs || 0
            }
        });

        if (created) {
            // 2. Update User Interests (Implicit/Weak Signal)
            // Weight is lower than a Like (e.g., 0.2 vs 1.0)
            const post = await Post.findByPk(postId);
            if (post && post.tags) {
                const user = await User.findByPk(userId);
                // Only boost if they spent meaningful time (> 1s) OR it's a generic impression
                const weight = (timeSpentMs && timeSpentMs > 3000) ? 0.5 : 0.1;
                await updateUserInterests(user, post.tags, weight);
            }
        }

        res.status(200).json({ message: 'View recorded' });
    } catch (error) {
        console.error('💥 Error recording view:', error);
        // Don't block client on view error
        res.status(200).json({ message: 'Error ignored' });
    }
};
