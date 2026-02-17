const cron = require('node-cron');
const contentService = require('../services/contentService');

const initCronJobs = () => {
    // Run every 2 minutes for "live" feel
    cron.schedule('*/2 * * * *', async () => {
        console.log('⏰ Cron: Triggering scheduled content fetch...');
        await contentService.fetchAndCreatePosts();
    });

    console.log('✅ Cron Jobs Initialized: [Content Fetch - 15m]');
};

module.exports = { initCronJobs };
