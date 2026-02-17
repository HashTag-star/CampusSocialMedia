const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const Block = sequelize.define('Block', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true
    },
    blocker_id: {
        type: DataTypes.UUID,
        allowNull: false
    },
    blocked_id: {
        type: DataTypes.UUID,
        allowNull: false
    }
}, {
    timestamps: true,
    tableName: 'blocks',
    indexes: [
        {
            unique: true,
            fields: ['blocker_id', 'blocked_id']
        }
    ]
});

module.exports = Block;
