const { Post, User, University, sequelize } = require('../models');

exports.createPost = async (req, res) => {
    try {
        const { caption, location, tagged_users, music_metadata } = req.body;
        const userId = req.user.id;
        
        let user = await User.findByPk(userId);
        
        // Fallback for Mock User (Bypass Mode)
        if (!user && userId === '11111111-1111-1111-1111-111111111111') {
            let [stanford] = await University.findOrCreate({
                where: { domain: 'stanford.edu' },
                defaults: {
                    id: '99999999-9999-9999-9999-999999999999',
                    name: 'Stanford University',
                    domain: 'stanford.edu',
                    logo_url: 'https://upload.wikimedia.org/wikipedia/commons/4/4b/Stanford_Cardinal_logo.svg'
                }
            });

            [user] = await User.findOrCreate({
                where: { id: userId },
                defaults: {
                    id: userId,
                    email: 'mock@test.com',
                    password_hash: 'mock_hash',
                    university_id: stanford.id,
                    is_verified_student: true,
                    profile_data: { name: 'Demo User', bio: 'Just testing things out.' }
                }
            });
        }

        if (!user) return res.status(404).json({ message: 'User not found' });

        let mediaUrl = null;
        let mediaType = 'none';
        let mediaUrls = [];

        // Handle multi-file uploads
        const uploadedUrls = req.uploadedUrls || [];

        if (uploadedUrls.length > 1) {
            mediaType = 'carousel';
            mediaUrls = uploadedUrls;
            mediaUrl = uploadedUrls[0]; // First image as thumbnail
        } else if (uploadedUrls.length === 1) {
            mediaUrl = uploadedUrls[0];
            // Determine type from first uploaded file
            const firstFile = req.files[0];
            if (firstFile.mimetype.startsWith('video')) {
                mediaType = 'video';
            } else {
                mediaType = 'image';
            }
        }

        // Parse location if it's a string
        let parsedLocation = null;
        if (location) {
            try {
                parsedLocation = typeof location === 'string' ? JSON.parse(location) : location;
            } catch (e) {
                parsedLocation = { name: location };
            }
        }

        // Parse tagged_users if string
        let parsedTaggedUsers = [];
        if (tagged_users) {
            try {
                parsedTaggedUsers = typeof tagged_users === 'string' ? JSON.parse(tagged_users) : tagged_users;
            } catch (e) {
                parsedTaggedUsers = [];
            }
        }

        // Parse music_metadata if string
        let parsedMusic = null;
        if (music_metadata) {
            try {
                parsedMusic = typeof music_metadata === 'string' ? JSON.parse(music_metadata) : music_metadata;
            } catch (e) {
                parsedMusic = null;
            }
        }

        // Tag extraction from caption
        const tags = (caption || '').match(/#[a-z0-9_]+/gi)?.map(tag => tag.slice(1)) || [];

        const newPost = await Post.create({
            user_id: user.id,
            university_id: user.university_id,
            caption,
            media_url: mediaUrl,
            media_type: mediaType,
            media_urls: mediaUrls,
            tags,
            location: parsedLocation,
            tagged_users: parsedTaggedUsers,
            music_metadata: parsedMusic,
        });

        res.status(201).json(newPost);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

exports.getCampusFeed = async (req, res) => {
    try {
        const userId = req.user.id;
        let user = await User.findByPk(userId);

        // Fallback for Mock User (Bypass Mode)
        // Fallback for Mock User (Bypass Mode)
        if (!user && userId === '11111111-1111-1111-1111-111111111111') {
             // Try to find Stanford to match Content Bot
             const stanford = await University.findOne({ where: { domain: 'stanford.edu' } });
             user = {
                id: userId,
                university_id: stanford ? stanford.id : '00000000-0000-0000-0000-000000000000',
             };
        }

        if (!user) {
             return res.json([]); 
        }

        // Build where clause — if no university, show all posts
        const whereClause = {};
        if (user.university_id) {
            whereClause[require('sequelize').Op.or] = [
                { university_id: user.university_id },
                { university_id: '99999999-9999-9999-9999-999999999999' } // Content University (Global News)
            ];
        }

        const posts = await Post.findAll({
            where: whereClause,
            attributes: {
                include: [
                    [sequelize.literal('(SELECT COUNT(*)::int FROM "likes" WHERE "likes"."post_id" = "Post"."id")'), 'likesCount'],
                    [sequelize.literal('(SELECT COUNT(*)::int FROM "comments" WHERE "comments"."post_id" = "Post"."id")'), 'commentsCount'],
                    [sequelize.literal(`(SELECT EXISTS(SELECT 1 FROM "likes" WHERE "likes"."post_id" = "Post"."id" AND "likes"."user_id" = '${userId}'))`), 'isLikedByMe']
                ]
            },
            include: [
                { 
                    model: User, 
                    attributes: ['id', 'email', 'profile_data'] 
                }
            ],
            order: [['createdAt', 'DESC']]
        });

        res.json(posts);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

const recommendationService = require('../services/recommendationService');

exports.getHomeFeed = async (req, res) => {
    try {
        const userId = req.user.id;
        
        // Get list of users I follow
        const user = await User.findByPk(userId, {
            include: [{ model: User, as: 'Following', attributes: ['id'] }]
        });

        const followingIds = user.Following.map(u => u.id);
        followingIds.push(userId); // Include own posts

        const posts = await Post.findAll({
            where: { user_id: followingIds },
            attributes: {
                include: [
                    [sequelize.literal('(SELECT COUNT(*)::int FROM "likes" WHERE "likes"."post_id" = "Post"."id")'), 'likesCount'],
                    [sequelize.literal('(SELECT COUNT(*)::int FROM "comments" WHERE "comments"."post_id" = "Post"."id")'), 'commentsCount'],
                    [sequelize.literal(`(SELECT EXISTS(SELECT 1 FROM "likes" WHERE "likes"."post_id" = "Post"."id" AND "likes"."user_id" = '${userId}'))`), 'isLikedByMe']
                ]
            },
            include: [
                { 
                    model: User, 
                    attributes: ['id', 'email', 'profile_data'] 
                }
            ],
            order: [['createdAt', 'DESC']]
        });

        res.json(posts);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

exports.getForYouFeed = async (req, res) => {
    try {
        const userId = req.user.id;
        const { limit, cursor, direction } = req.query; // Query params
        const posts = await recommendationService.getForYouFeed(userId, { 
            limit: limit ? parseInt(limit) : 20,
            cursor, 
            direction 
        });
        res.json(posts);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

exports.searchPosts = async (req, res) => {
    try {
        const { q } = req.query; // Search query
        if (!q) return res.json([]);

        const userId = req.user.id; // Needed for isLikedByMe

        const posts = await Post.findAll({
            where: {
                [require('sequelize').Op.or]: [
                    { caption: { [require('sequelize').Op.iLike]: `%${q}%` } },
                    { tags: { [require('sequelize').Op.contains]: [q] } } // Postgres Array check
                ]
            },
            attributes: {
                include: [
                    [sequelize.literal('(SELECT COUNT(*)::int FROM "likes" WHERE "likes"."post_id" = "Post"."id")'), 'likesCount'],
                    [sequelize.literal('(SELECT COUNT(*)::int FROM "comments" WHERE "comments"."post_id" = "Post"."id")'), 'commentsCount'],
                    [sequelize.literal(`(SELECT EXISTS(SELECT 1 FROM "likes" WHERE "likes"."post_id" = "Post"."id" AND "likes"."user_id" = '${userId}'))`), 'isLikedByMe']
                ]
            },
            include: [
                { 
                    model: User, 
                    attributes: ['id', 'email', 'profile_data'] 
                }
            ],
            limit: 20,
            order: [['createdAt', 'DESC']]
        });

        res.json(posts);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Get Single Post by ID
exports.getPostById = async (req, res) => {
    try {
        const post = await Post.findByPk(req.params.postId, {
            include: [
                { model: User, attributes: ['id', 'email', 'profile_data'] }
            ]
        });

        if (!post) return res.status(404).json({ message: 'Post not found' });

        const { Like, Comment } = require('../models');
        const likesCount = await Like.count({ where: { post_id: post.id } });
        const commentsCount = await Comment.count({ where: { post_id: post.id } });
        const isLikedByMe = await Like.findOne({ where: { post_id: post.id, user_id: req.user.id } });

        res.json({
            ...post.toJSON(),
            likesCount,
            commentsCount,
            isLikedByMe: !!isLikedByMe,
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Update Post (caption only)
exports.updatePost = async (req, res) => {
    try {
        const post = await Post.findByPk(req.params.postId);

        if (!post) return res.status(404).json({ message: 'Post not found' });
        if (post.user_id !== req.user.id) return res.status(403).json({ message: 'Not authorized' });

        const { caption } = req.body;
        if (caption !== undefined) {
            post.caption = caption;
            post.tags = (caption || '').match(/#[a-z0-9_]+/gi)?.map(tag => tag.slice(1)) || [];
        }
        await post.save();
        res.json(post);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Delete Post
exports.deletePost = async (req, res) => {
    try {
        const post = await Post.findByPk(req.params.postId);

        if (!post) return res.status(404).json({ message: 'Post not found' });
        if (post.user_id !== req.user.id) return res.status(403).json({ message: 'Not authorized' });

        await post.destroy();
        res.json({ message: 'Post deleted' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Get Shorts (Video-only posts for Reels feed)
exports.getShorts = async (req, res) => {
    try {
        const userId = req.user.id;
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 20;
        const offset = (page - 1) * limit;

        const posts = await Post.findAll({
            where: { media_type: 'video' },
            attributes: {
                include: [
                    [sequelize.literal('(SELECT COUNT(*)::int FROM "likes" WHERE "likes"."post_id" = "Post"."id")'), 'likesCount'],
                    [sequelize.literal('(SELECT COUNT(*)::int FROM "comments" WHERE "comments"."post_id" = "Post"."id")'), 'commentsCount'],
                    [sequelize.literal(`(SELECT EXISTS(SELECT 1 FROM "likes" WHERE "likes"."post_id" = "Post"."id" AND "likes"."user_id" = '${userId}'))`), 'isLikedByMe']
                ]
            },
            include: [
                {
                    model: User,
                    attributes: ['id', 'email', 'profile_data']
                }
            ],
            order: [['createdAt', 'DESC']],
            limit,
            offset
        });

        res.json(posts);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};
