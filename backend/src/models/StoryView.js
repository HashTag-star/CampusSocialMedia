const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');
 
const StoryView = sequelize.define('StoryView', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true
    },
    story_id: {
        type: DataTypes.UUID,
        allowNull: false
    },
    viewer_id: {
        type: DataTypes.UUID,
        allowNull: false
    },
    liked: {
        type: DataTypes.BOOLEAN,
        defaultValue: false
    },
    reaction: {
        type: DataTypes.STRING, // emoji or null
        allowNull: true
    },
    reply: {
        type: DataTypes.TEXT, // text reply or null
        allowNull: true
    }
}, {
    timestamps: true,
    tableName: 'story_views',
    indexes: [
        {
            unique: true,
            fields: ['story_id', 'viewer_id']
        }
    ]
});

module.exports = StoryView;
