require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const { connectDB, sequelize } = require('./config/database');
const authRoutes = require('./routes/authRoutes');
const postRoutes = require('./routes/postRoutes');
const userRoutes = require('./routes/userRoutes');
const courseRoutes = require('./routes/courseRoutes');
const eventRoutes = require('./routes/eventRoutes');
const spaceRoutes = require('./routes/spaceRoutes');
const storyRoutes = require('./routes/storyRoutes');
const commentRoutes = require('./routes/commentRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const messageRoutes = require('./routes/messageRoutes');
const interactionRoutes = require('./routes/interactionRoutes');
const adminRoutes = require('./routes/adminRoutes');
const path = require('path');
const { initCronJobs } = require('./jobs/cron');
const contentService = require('./services/contentService');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(express.json());
app.use(cors());
app.use(helmet());
app.use(morgan('dev'));
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// Debug Middleware: Log all requests
app.use((req, res, next) => {
    console.log(`📨 ${req.method} ${req.url}`);
    console.log('Headers:', req.headers);
    next();
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/posts', postRoutes);
app.use('/api/users', userRoutes); // User routes + Follow routes
app.use('/api/courses', courseRoutes);
app.use('/api/events', eventRoutes);
app.use('/api/spaces', spaceRoutes);
app.use('/api/stories', storyRoutes);
app.use('/api/comments', commentRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api/interactions', interactionRoutes);
app.use('/api/admin', adminRoutes);

// Basic Route
app.get('/', (req, res) => {
    res.json({ message: 'Welcome to the University Social Media Platform API' });
});

// Health Check
app.get('/health', (req, res) => {
    res.status(200).json({ status: 'OK', uptime: process.uptime() });
});

// Manual Trigger for Cron (Dev only)
app.post('/api/cron/trigger', async (req, res) => {
    console.log('👆 Manual Trigger: Content Fetch');
    contentService.fetchAndCreatePosts().catch(err => console.error(err));
    res.json({ message: 'Content fetch triggered in background' });
});

// Start Server
const startServer = async () => {
    await connectDB();
    // Sync models
    await sequelize.sync({ alter: true }); // Enabled for schema updates
    // await sequelize.sync(); // Create if not exists, do not alter
    console.log('Database synced');
    
    // Initialize Cron Jobs
    initCronJobs();

    app.listen(PORT, () => {
        console.log(`Server running on port ${PORT}`);
    });
};

startServer();

