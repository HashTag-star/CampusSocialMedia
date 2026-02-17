/**
 * Basic Automod Service
 * Filters content for spam, scams, and hate speech.
 */

// BLOCK: Hard slurs, scam domains, severe toxicity
const BANNED_WORDS = [
    'nigger', 'faggot', 'kike', 'chink', 'wetback', // Hard Slurs
    'free-crypto', 'whatsapp-group', 'investment-return', // Spam/Scam keywords
    'kill yourself', 'kys'
];

// FLAG: Mild profanity, controversial topics, adult themes
const SENSITIVE_WORDS = [
    'fuck', 'shit', 'bitch', 'asshole', 'cunt', 'dick', 'pussy', 'sex', 'nude',
    'suicide', 'depression', 'drug', 'weed', 'cocaine', 'heroin',
    'politics', 'trump', 'biden', 'election' // Political topics often flagged for optional filtering
];

exports.analyzeText = (text) => {
    if (!text) return { action: 'allow', tags: [] };
    
    const lowerText = text.toLowerCase();
    
    // 1. Check Block List
    for (const word of BANNED_WORDS) {
        if (lowerText.includes(word)) {
            return { action: 'block', reason: 'Content contains prohibited language.' };
        }
    }

    // 2. Check Sensitive List
    const tags = [];
    let isSensitive = false;
    
    for (const word of SENSITIVE_WORDS) {
        if (lowerText.includes(word)) {
            isSensitive = true;
            tags.push('sensitive');
            break; // Mark sensitive once matching
        }
    }

    if (isSensitive) {
        return { action: 'flag', tags };
    }

    return { action: 'allow', tags: [] };
};
