const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Post = sequelize.define('Post', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true
    },
    user_id: {
        type: DataTypes.UUID,
        allowNull: false
    },
    university_id: { // Posts can be tied to a university
        type: DataTypes.UUID,
        allowNull: true
    },
    caption: {
        type: DataTypes.TEXT,
        allowNull: true
    },
    media_url: {
        type: DataTypes.STRING,
        allowNull: true // Could be text-only post
    },
    media_type: {
        type: DataTypes.STRING, // Changed from ENUM to prevent postgres strict type errors
        defaultValue: 'none'
    },
    media_urls: {
        type: DataTypes.JSONB, // Array of strings e.g. ["img1.jpg", "img2.jpg"]
        defaultValue: []
    },
    music_metadata: {
        type: DataTypes.JSONB, // { "title": "Song", "artist": "Artist", "preview_url": "..." }
        allowNull: true
    },
    tags: {
        type: DataTypes.JSONB, 
        defaultValue: []
    },
    location: {
        type: DataTypes.JSONB, // { "name": "Stanford Campus", "lat": 37.4, "lng": -122.1 }
        allowNull: true
    },
    tagged_users: {
        type: DataTypes.JSONB, // Array of user IDs
        defaultValue: []
    }
}, {
    timestamps: true,
    tableName: 'posts'
});

module.exports = Post;
