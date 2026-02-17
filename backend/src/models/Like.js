const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Like = sequelize.define('Like', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true
    }
}, {
    timestamps: true,
    tableName: 'likes',
    indexes: [
        {
            unique: true,
            fields: ['user_id', 'post_id']
        }
    ]
});

module.exports = Like;
