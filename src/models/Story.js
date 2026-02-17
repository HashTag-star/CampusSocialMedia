const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Story = sequelize.define('Story', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true
    },
    user_id: {
        type: DataTypes.UUID,
        allowNull: false
    },
    university_id: {
        type: DataTypes.UUID,
        allowNull: true
    },
    media_url: {
        type: DataTypes.STRING,
        allowNull: false
    },
    media_type: {
        type: DataTypes.STRING, // 'image' or 'video'
        defaultValue: 'image'
    },
    caption: {
        type: DataTypes.TEXT,
        allowNull: true
    },
    expires_at: {
        type: DataTypes.DATE,
        allowNull: false
    }
}, {
    timestamps: true,
    tableName: 'stories'
});

module.exports = Story;
