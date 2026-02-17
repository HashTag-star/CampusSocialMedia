const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const CommentLike = sequelize.define('CommentLike', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true
    }
}, {
    timestamps: true,
    tableName: 'comment_likes',
    indexes: [
        {
            unique: true,
            fields: ['user_id', 'comment_id']
        }
    ]
});

module.exports = CommentLike;
