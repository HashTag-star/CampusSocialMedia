require('dotenv').config();
const { connectDB } = require('./src/config/database');
const contentService = require('./src/services/contentService');

const run = async () => {
    await connectDB();
    await contentService.fetchAndCreatePosts();
    process.exit(0);
};

run();
 