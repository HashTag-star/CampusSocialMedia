const cron = require('node-cron');
const contentService = require('../services/contentService');

const initCronJobs = () => {
    // Run every 15 minutes to prevent overload
    cron.schedule('*/15 * * * *', async () => {
        console.log('⏰ Cron: Triggering scheduled content fetch...');
        await contentService.fetchAndCreatePosts();
    });

    console.log('✅ Cron Jobs Initialized: [Content Fetch - 15m]');
};

module.exports = { initCronJobs };
