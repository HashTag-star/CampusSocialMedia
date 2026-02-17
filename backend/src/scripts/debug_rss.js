const Parser = require('rss-parser');

const parser = new Parser({
    headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
});

const FEEDS = [
    'https://techcrunch.com/feed/',
    'https://www.wired.com/feed/rss',
    'https://news.stanford.edu/feed'
];

async function inspectFeeds() {
    for (const url of FEEDS) {
        try {
            console.log(`\n📡 Fetching ${url}...`);
            const feed = await parser.parseURL(url);
            console.log(`✅ Success! Standard fields:`);
            const item = feed.items[0];
            
            console.log('Title:', item.title);
            console.log('Link:', item.link);
            console.log('Enclosure:', item.enclosure);
            console.log('Media Content:', item['media:content']);
            console.log('Media Group:', item['media:group']);
            console.log('Content Snippet (first 100):', item.contentSnippet?.substring(0, 100));
            console.log('Content (first 100):', item.content?.substring(0, 100));
            
            // Full item keys to see if we missed anything
            console.log('All Keys:', Object.keys(item));
            
        } catch (error) {
            console.error(`❌ Error fetching ${url}:`, error.message);
        }
    }
}

inspectFeeds();
