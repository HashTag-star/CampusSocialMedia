const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Course = sequelize.define('Course', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true
    },
    university_id: {
        type: DataTypes.UUID,
        allowNull: false
    },
    code: {
        type: DataTypes.STRING,
        allowNull: false // e.g., "CS101"
    },
    name: {
        type: DataTypes.STRING,
        allowNull: false // e.g., "Introduction to Computer Science"
    },
    semester: {
        type: DataTypes.STRING,
        allowNull: false // e.g., "Fall 2026"
    }
}, {
    timestamps: true,
    tableName: 'courses',
    indexes: [
        {
            unique: true,
            fields: ['university_id', 'code', 'semester']
        }
    ]
});

module.exports = Course;
