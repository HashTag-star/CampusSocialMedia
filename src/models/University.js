const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const University = sequelize.define('University', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true
    },
    name: {
        type: DataTypes.STRING,
        allowNull: false
    },
    domain: {
        type: DataTypes.STRING,
        allowNull: false,
        unique: true // e.g., "stanford.edu"
    },
    logo_url: {
        type: DataTypes.STRING,
        allowNull: true
    }
}, {
    timestamps: true,
    tableName: 'universities'
});

module.exports = University;
