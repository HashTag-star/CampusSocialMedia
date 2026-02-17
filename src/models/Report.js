const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Report = sequelize.define('Report', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true
    },
    reporter_id: {
        type: DataTypes.UUID,
        allowNull: false
    },
    target_type: {
        type: DataTypes.ENUM('post', 'comment', 'user', 'story'),
        allowNull: false
    },
    target_id: {
        type: DataTypes.UUID,
        allowNull: false
    },
    reason: {
        type: DataTypes.STRING,
        allowNull: false
    },
    description: {
        type: DataTypes.TEXT,
        allowNull: true
    },
    status: {
        type: DataTypes.ENUM('pending', 'resolved', 'dismissed'),
        defaultValue: 'pending'
    }
}, {
    timestamps: true,
    tableName: 'reports'
});

module.exports = Report;
