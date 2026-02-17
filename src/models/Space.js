const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Space = sequelize.define('Space', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true
    },
    university_id: {
        type: DataTypes.UUID,
        allowNull: false
    },
    host_id: {
        type: DataTypes.UUID,
        allowNull: false
    },
    title: {
        type: DataTypes.STRING,
        allowNull: false
    },
    topic: {
        type: DataTypes.STRING,
        allowNull: false // e.g., "Exam Prep", "Chill", "Debate"
    },
    is_active: {
        type: DataTypes.BOOLEAN,
        defaultValue: true
    },
    participants_count: {
        type: DataTypes.INTEGER,
        defaultValue: 0
    }
}, {
    timestamps: true,
    tableName: 'spaces'
});

module.exports = Space;
