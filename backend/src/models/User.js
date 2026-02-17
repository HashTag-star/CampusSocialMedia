const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const User = sequelize.define('User', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true
    },
    email: { // must be .edu
        type: DataTypes.STRING,
        allowNull: false,
        unique: true,
        validate: {
            isEmail: true
        }
    },
    password_hash: {
        type: DataTypes.STRING,
        allowNull: false
    },
    is_verified_student: {
        type: DataTypes.BOOLEAN,
        defaultValue: false
    },
    role: {
        type: DataTypes.ENUM('user', 'admin'),
        defaultValue: 'user'
    },
    is_banned: {
        type: DataTypes.BOOLEAN,
        defaultValue: false
    },
    university_id: {
        type: DataTypes.UUID,
        allowNull: true // Can be null initially until verified
    },
    profile_data: {
        type: DataTypes.JSONB,
        defaultValue: {}
    },
    interests: {
        type: DataTypes.JSONB, // { "tech": 5, "music": 2 }
        defaultValue: {}
    }
}, {
    timestamps: true,
    tableName: 'users'
});

module.exports = User;
