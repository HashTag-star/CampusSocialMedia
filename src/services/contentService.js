const Parser = require('rss-parser');
const { Post, User, University } = require('../models');
const { Op } = require('sequelize');

const BOT_USER_ID = '11111111-1111-1111-1111-111111111111';
const STANFORD_ID = '99999999-9999-9999-9999-999999999999';

// Custom headers to avoid 403 errors (e.g. Stanford) and capture extra fields
const FEEDS = [
    // University News
    { 
        url: 'http://news.mit.edu/rss/feed', 
        category: 'Research',
        botName: 'MIT News',
        botAvatar: 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0c/MIT_logo.svg/1024px-MIT_logo.svg.png',
        botId: '22222222-2222-2222-2222-222222222222'
    },
    { 
        url: 'https://news.stanford.edu/feed', 
        category: 'Campus',
        botName: 'Stanford News',
        botAvatar: 'https://upload.wikimedia.org/wikipedia/commons/4/4b/Stanford_Cardinal_logo.svg',
        botId: '33333333-3333-3333-3333-333333333333'
    },
    { 
        url: 'https://3news.com/feed', 
        category: 'Ghana Campus',
        botName: '3News Ghana',
        botAvatar: 'https://pbs.twimg.com/profile_images/1612741824765661186/3u6Y2qS__400x400.jpg',
        botId: '44444444-4444-4444-4444-444444444444'
    },
    
    // Tech & Culture
    { 
        url: 'https://techcabal.com/feed/', 
        category: 'Africa Tech',
        botName: 'TechCabal',
        botAvatar: 'https://techcabal.com/wp-content/uploads/2020/10/TechCabal-Logo-2020.png',
        botId: '55555555-5555-5555-5555-555555555555' 
    },
    { 
        url: 'https://www.wired.com/feed/rss', 
        category: 'Tech',
        botName: 'Wired',
        botAvatar: 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/95/Wired_logo.svg/1200px-Wired_logo.svg.png',
        botId: '66666666-6666-6666-6666-666666666666'
    },
    { 
        url: 'https://www.reddit.com/r/college/.rss', 
        category: 'Social',
        botName: 'r/college',
        botAvatar: 'https://www.iconarchive.com/download/i109559/mjcen/reddit/reddit-logo.1024.png',
        botId: '77777777-7777-7777-7777-777777777777'
    }
];

const parser = new Parser({
    customFields: {
        item: ['media:group', 'media:content', 'content:encoded']
    },
    headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
});

const getOrCreateBotUser = async (feedConfig) => {
    let bot = await User.findByPk(feedConfig.botId);
    
    if (!bot) {
        // Ensure "Content University" exists
        let stanford = await University.findByPk(STANFORD_ID);
        if (!stanford) {
             [stanford] = await University.findOrCreate({
                where: { id: STANFORD_ID },
                defaults: {
                    name: 'Stanford University',
                    domain: 'stanford.edu',
                    logo_url: 'https://upload.wikimedia.org/wikipedia/commons/4/4b/Stanford_Cardinal_logo.svg'
                }
            });
        }

        bot = await User.create({
            id: feedConfig.botId,
            email: `bot.${feedConfig.botName.replace(/\s+/g, '').toLowerCase()}@campus.edu`,
            password: 'legacy_bot_hash',
            password_hash: 'legacy_bot_hash',
            university_id: stanford.id,
            profile_data: {
                name: feedConfig.botName,
                bio: `Official feed for ${feedConfig.botName}.`,
                avatar_url: feedConfig.botAvatar
            },
            is_verified_student: true
        });
    }
    return bot;
};

exports.fetchAndCreatePosts = async () => {
    console.log('🔄 Cron: Starting Content Fetch...');

    for (const feedSource of FEEDS) {
        try {
            const botUser = await getOrCreateBotUser(feedSource);
            
            const feed = await parser.parseURL(feedSource.url);
            console.log(`📡 Fetching from: ${feed.title} as ${botUser.profile_data.name}`);

            // Process only the latest 2 items per source to balance feed
            for (const item of feed.items.slice(0, 2)) {
                
                const existingPost = await Post.findOne({
                    where: {
                        caption: { [Op.like]: `%${item.title}%` },
                        user_id: botUser.id
                    }
                });

                if (existingPost) {
                    continue; // Skip existing
                }

                // Extract image from content if possible
                let mediaUrl = null;
                let mediaType = 'none';
                let mediaUrls = [];
                let musicMetadata = null;

                // 1. Check for Enclosure (Standard Podcast/Media)
                if (item.enclosure && item.enclosure.url && item.enclosure.type?.startsWith('image')) {
                    mediaUrl = item.enclosure.url;
                    mediaUrls.push(mediaUrl);
                    mediaType = 'image';
                }
                
                // 2. Check for Media Content (Common in News Feeds)
                if (item['media:content']) {
                     const media = item['media:content'];
                     if (Array.isArray(media)) {
                        // Extract all images
                        const images = media.filter(m => m.$?.medium === 'image' || m.$?.type?.startsWith('image')).map(m => m.$?.url);
                        if (images.length > 0) {
                            mediaUrl = images[0]; // Primary
                            mediaUrls = images;
                            mediaType = images.length > 1 ? 'carousel' : 'image';
                        }
                     } else if (media.$ && media.$.url) {
                        mediaUrl = media.$.url;
                        mediaUrls.push(mediaUrl);
                        mediaType = 'image';
                     }
                }

                // 3. Check media:group (Wired often uses this)
                if (item['media:group']) {
                    const group = item['media:group'];
                    const content = group['media:content'];
                    if (Array.isArray(content)) {
                        const images = content.filter(m => m.$?.medium === 'image' || m.$?.type?.startsWith('image')).map(m => m.$?.url);
                        if (images.length > 0) {
                             mediaUrl = images[0];
                             mediaUrls = images;
                             mediaType = images.length > 1 ? 'carousel' : 'image';
                        }
                    }
                }

                // 4. Regex on content:encoded (Rich content often has the image)
                if (!mediaUrl && item['content:encoded']) {
                    const imgMatch = item['content:encoded'].match(/<img[^>]+src="([^">]+)"/);
                    if (imgMatch) {
                        mediaUrl = imgMatch[1];
                        mediaUrls.push(mediaUrl);
                        mediaType = 'image';
                    }
                }

                // 5. Fallback: Regex on content or description
                if (!mediaUrl) {
                    const rawContent = item.content || item.contentSnippet || '';
                    const imgMatch = rawContent.match(/<img[^>]+src="([^">]+)"/);
                    if (imgMatch) {
                        mediaUrl = imgMatch[1];
                        mediaUrls.push(mediaUrl);
                        mediaType = 'image';
                    }
                }

                // Mock Audio/Music for demo purposes (Randomly attach to 30% of posts)
                if (Math.random() > 0.7) {
                    const trendingTracks = [
                        { title: 'Campus Vibes', artist: 'LoFi Study', preview_url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3' },
                        { title: 'Morning Coffee', artist: 'Jazz Cafe', preview_url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3' },
                        { title: 'Focus Flow', artist: 'Deep Work', preview_url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3' }
                    ];
                    musicMetadata = trendingTracks[Math.floor(Math.random() * trendingTracks.length)];
                }

                // Create Post
                await Post.create({
                    user_id: botUser.id,
                    university_id: botUser.university_id,
                    caption: `${item.title}\n\n${item.contentSnippet?.slice(0, 150)}...\n\nRead more: ${item.link} #${feedSource.category.replace(/\s/g, '')} #News`,
                    media_url: mediaUrl,
                    media_type: mediaType,
                    media_urls: mediaUrls,
                    music_metadata: musicMetadata,
                    tags: [feedSource.category, 'News']
                });

                console.log(`✅ Posted: ${item.title}`);
            }

        } catch (error) {
            console.error(`⚠️ Error fetching ${feedSource.url}:`, error.message);
        }
    }
    console.log('🏁 Cron: Content Fetch Completed.');
};
