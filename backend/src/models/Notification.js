const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Notification = sequelize.define('Notification', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true
    },
    recipient_id: {
        type: DataTypes.UUID,
        allowNull: false
    },
    actor_id: {
        type: DataTypes.UUID,
        allowNull: true // System notifications might not have an actor
    },
    type: {
        type: DataTypes.ENUM('follow', 'like', 'comment', 'suggestion', 'message', 'system'),
        allowNull: false
    },
    entity_id: {
        type: DataTypes.UUID,
        allowNull: true // Post ID, Comment ID, etc.
    },
    message: {
        type: DataTypes.STRING,
        allowNull: true
    },
    is_read: {
        type: DataTypes.BOOLEAN,
        defaultValue: false
    }
}, {
    timestamps: true,
    tableName: 'notifications'
});

module.exports = Notification;
