const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const PostView = sequelize.define('PostView', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true
    },
    post_id: {
        type: DataTypes.UUID,
        allowNull: false
    },
    viewer_id: {
        type: DataTypes.UUID,
        allowNull: false
    },
    time_spent_ms: {
        type: DataTypes.INTEGER, // Time spent in milliseconds
        defaultValue: 0
    },
    interacted: {
        type: DataTypes.BOOLEAN, // True if scrolled past? Or explicitly clicked? For now just existence means view.
        defaultValue: false
    }
}, {
    timestamps: true,
    tableName: 'post_views',
    indexes: [
        {
            fields: ['post_id', 'viewer_id'] // Not unique, user can view multiple times? standardized metrics usually unique per session, but for simplicity let's just log. Actually X algo cares about re-engagement.
        }
    ]
});

module.exports = PostView;
