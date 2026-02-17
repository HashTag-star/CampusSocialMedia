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

// Rate Limiting (prevent brute force)
const rateLimit = require('express-rate-limit');
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // limit each IP to 100 requests per windowMs
    message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', limiter);

const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 10, // limit login attempts
    message: 'Too many login attempts, please try again later.'
});
app.use('/api/auth/login', authLimiter);

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

// Socket.io Setup
const http = require('http');
const { Server } = require('socket.io');

const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: "*", // Allow all origins (for mobile app)
        methods: ["GET", "POST"]
    }
});

// Export io for use in controllers
app.set('io', io);

// Socket Middleware (Auth)
const jwt = require('jsonwebtoken');
io.use((socket, next) => {
    const token = socket.handshake.auth.token;
    if (!token) return next(new Error('Authentication error'));
    
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        socket.user = decoded;
        next();
    } catch (err) {
        next(new Error('Authentication error'));
    }
});

io.on('connection', (socket) => {
    console.log(`🔌 User connected: ${socket.user.id}`);

    // Join a conversation room
    socket.on('join_conversation', (conversationId) => {
        socket.join(`conversation_${conversationId}`);
        console.log(`User ${socket.user.id} joined conversation ${conversationId}`);
    });

    // Typing indicators
    socket.on('typing', (conversationId) => {
        socket.to(`conversation_${conversationId}`).emit('typing', {
            userId: socket.user.id,
            conversationId
        });
    });

    socket.on('stop_typing', (conversationId) => {
        socket.to(`conversation_${conversationId}`).emit('stop_typing', {
            userId: socket.user.id,
            conversationId
        });
    });

    socket.on('disconnect', () => {
        console.log('User disconnected');
    });
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

    server.listen(PORT, () => {
        console.log(`Server running on port ${PORT}`);
    });
};

startServer();

