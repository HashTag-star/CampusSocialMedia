const { User, Post, Like, Comment, Follow, PostView, Block } = require('../models');
const { Op } = require('sequelize');

const TASTE_CLUSTERS = {
    'tech': ['coding', 'ai', 'javascript', 'python', 'startup', 'crypto', 'webdev', 'linux', 'programming'],
    'sports': ['football', 'basketball', 'gym', 'fitness', 'soccer', 'nfl', 'nba', 'workout'],
    'art': ['design', 'fashion', 'photography', 'art', 'drawing', 'music', 'creative'],
    'campus': ['study', 'library', 'exam', 'party', 'dorm', 'food', 'collegelife', 'student'],
    'news': ['politics', 'news', 'world', 'economy', 'current_events']
};

/**
 * X/Instagram Style Recommendation Engine
 * 
 * Pipeline:
 * 1. User Context: Fetch user profile, interests, and following list.
 * 2. Candidate Generation: 
 *    - Network: Posts from following (high priority).
 *    - Viral: High engagement posts from University/Global.
 *    - Topics: Posts matching user interests.
 * 3. Scoring: Weighted sum of EdgeRank, InterestMatch, ClusterMatch, Recency.
 * 4. Diversity: Penalty for repetitive authors.
 */

exports.getForYouFeed = async (userId, options = {}) => {
    const { limit = 20, cursor = null, direction = 'older' } = options; // direction: 'newer' (refresh) or 'older' (scroll)

    // --- 1. User Context ---
    let user = await User.findByPk(userId, {
        include: [{ model: User, as: 'Following', attributes: ['id'] }]
    });

    if (!user) return [];

    const followingIds = user.Following.map(u => u.id);
    const userInterests = user.interests || {}; // { "tech": 5, "music": 2 }
    const interestTags = Object.keys(userInterests);

    // 0. Get Blocked Users (Both directions)
    const blocks = await Block.findAll({
        where: {
            [Op.or]: [
                { blocker_id: userId },
                { blocked_id: userId }
            ]
        }
    });
    const blockedUserIds = blocks.map(b => b.blocker_id === userId ? b.blocked_id : b.blocker_id);

    // Common WHERE clause for exclusion
    const excludeBlocked = {
        user_id: { [Op.notIn]: [...blockedUserIds, userId] } // Also exclude own posts
    };
    
    // --- Time Constraint Helper ---
    // If refreshing (newer), we want posts created AFTER the cursor.
    // If scrolling (older), we want posts created BEFORE the cursor.
    // If no cursor (first load), we want recent posts.
    const timeOperator = direction === 'newer' ? Op.gt : Op.lt;
    const timeFilter = cursor ? { [timeOperator]: new Date(cursor) } : { [Op.lte]: new Date() };

    // --- 2. Candidate Generation (Recall) ---
    // We fetch separate buckets to ensure diversity in the candidate pool
    
    // A. Network Candidates (Recent posts from following)
    const networkCandidates = await Post.findAll({
        where: { 
            user_id: followingIds,
            createdAt: timeFilter
        },
        limit: limit, // Fetch slightly more to allow for ranking
        order: [['createdAt', 'DESC']],
        include: [
            { model: User, attributes: ['id', 'email', 'profile_data'] },
            { model: Like, attributes: ['id'] },
            { model: Comment, attributes: ['id'] }
        ]
    });

    // B. Viral/Trending (University & Global)
    // Heuristic: Posts with > 5 likes in last 24h
    // For pagination, we just respect the time filter
    const viralCandidates = await Post.findAll({
        where: {
            createdAt: { 
                [Op.and]: [
                    timeFilter,
                    { [Op.gte]: new Date(Date.now() - 72 * 60 * 60 * 1000) } // Max 3 days old for viral
                ]
            },
            user_id: { [Op.notIn]: [...followingIds, userId, ...blockedUserIds] } // Exclude following + blocked
        },
        limit: limit,
        order: [['createdAt', 'DESC']],
        include: [
            { model: User, attributes: ['id', 'email', 'profile_data'] },
            { model: Like, attributes: ['id'] },
            { model: Comment, attributes: ['id'] }
        ]
    });

    // C. Interest Match (Topic Exploration)
    let topicCandidates = [];
    if (interestTags.length > 0) {
        topicCandidates = await Post.findAll({
            where: {
                tags: { [Op.overlap]: interestTags },
                user_id: { [Op.notIn]: [...followingIds, userId, ...blockedUserIds] }, // Exclude following + blocked
                createdAt: {
                     [Op.and]: [
                        timeFilter,
                        { [Op.gte]: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) } // Max 7 days
                    ]
                }
            },
            limit: limit,
            order: [['createdAt', 'DESC']],
            include: [
                { model: User, attributes: ['id', 'email', 'profile_data'] },
                { model: Like, attributes: ['id'] },
                { model: Comment, attributes: ['id'] }
            ]
        });
    }

    // Combine & Deduplicate
    const allCandidates = [...networkCandidates, ...viralCandidates, ...topicCandidates];
    const uniqueCandidates = Array.from(new Map(allCandidates.map(p => [p.id, p])).values());

    // If no candidates found, return early
    if (uniqueCandidates.length === 0) return [];

    // --- 3. Scoring Engine ---
    const scoredPosts = uniqueCandidates.map(post => {
        let score = 0;
        const isFollowing = followingIds.includes(post.user_id);
        
        // Weights
        const W_RECENCY = 10.0;
        const W_LIKE = 1.0;
        const W_COMMENT = 3.0;
        const W_INTEREST = 5.0;
        const W_NETWORK = 20.0; // Huge boost for following

        // 1. Recency Score (Decay)
        const hoursAgo = (Date.now() - new Date(post.createdAt)) / (1000 * 60 * 60);
        const recencyScore = 1 / Math.pow(hoursAgo + 2, 1.8); // 1/(x+2)^1.8 decay curve
        score += recencyScore * W_RECENCY * 100; // Scale up

        // 2. Engagement (Popularity)
        const likes = post.Likes.length;
        const comments = post.Comments.length;
        score += (likes * W_LIKE) + (comments * W_COMMENT);

        // 3. Interest & Cluster Match
        const postTags = post.tags || [];
        let interestScore = 0;
        let clusterScore = 0;

        // Pre-calculate user clusters for performance (could be done outside loop)
        const userClusters = new Set();
        Object.keys(userInterests).forEach(tag => {
            for (const [clusterName, tags] of Object.entries(TASTE_CLUSTERS)) {
                if (tags.includes(tag)) userClusters.add(clusterName);
            }
        });

        postTags.forEach(tag => {
            // Direct Match
            if (userInterests[tag]) {
                interestScore += userInterests[tag];
            }

            // Cluster Match
            for (const [clusterName, tags] of Object.entries(TASTE_CLUSTERS)) {
                if (tags.includes(tag) && userClusters.has(clusterName)) {
                    clusterScore += 2.0; // Boost for matching cluster
                }
            }
        });

        score += Math.min(interestScore, 20) * W_INTEREST; 
        score += Math.min(clusterScore, 10) * 3.0; // Cap cluster boost

        // 4. Network Boost
        if (isFollowing) score += W_NETWORK;

        // 5. University Boost
        if (post.university_id === user.university_id) score += 10;

        return { post, score, authorId: post.user_id };
    });

    // --- 4. Ranking & Diversity ---
    // Sort by score first
    scoredPosts.sort((a, b) => b.score - a.score);

    // Apply Diversity Penalty (limit posts from same author)
    const finalFeed = [];
    const authorCounts = {};

    for (const item of scoredPosts) {
        const authorId = item.authorId;
        const count = authorCounts[authorId] || 0;

        // Penalize score if author already has posts in feed
        if (count > 0) {
            item.score /= (count + 1); // Halve score for 2nd post, third for 3rd, etc.
        }

        if (count < 3) {
            finalFeed.push(item);
            authorCounts[authorId] = count + 1;
        }
    }

    // Since we are paging by TIME, we must maintain Chronological order within the scored validation?
    // Actually, Feed Algorithms usually break pure chronology for relevance.
    // BUT, for cursor pagination to work reliably without gaps/repeats, relying on 'createdAt' implies
    // we should return them roughly in time order OR we just rely on the fact that we fetched by time.
    // However, if we shuffle them by score, the 'last post' might not be the oldest, breaking the cursor.
    // X/Twitter solves this by having a "Home" (Algorithmic) vs "Latest" (Chronological).
    // For "Home", they usually use an internal cursor that isn't just time.
    
    // For this MVP, let's keep it simple:
    // We Re-Sort by CreatedAt DESC at the very end to ensure the 'last' item is truly the oldest,
    // so the next cursor works.
    // This sacrifices "perfect" scoring order for "stable" pagination.
    // The "Scoring" here acts as a filter: "Top N most relevant posts from this time window".
    
    // 1. Take top N specific by limit
    const topScored = finalFeed.slice(0, limit);
    
    // 2. Sort by Date DESC so cursor works for next page
    topScored.sort((a, b) => new Date(b.post.createdAt) - new Date(a.post.createdAt));

    // Return Post objects
    return topScored.map(item => item.post);
};
