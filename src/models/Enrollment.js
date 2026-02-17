const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Enrollment = sequelize.define('Enrollment', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true
    },
    role: {
        type: DataTypes.ENUM('Student', 'TA', 'Professor'),
        defaultValue: 'Student'
    }
}, {
    timestamps: true,
    tableName: 'enrollments',
    indexes: [
        {
            unique: true,
            fields: ['user_id', 'course_id']
        }
    ]
});

module.exports = Enrollment;
