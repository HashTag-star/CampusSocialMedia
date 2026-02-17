const { DataTypes } = require('sequelize');
const { sequelize } = require('../config/database');

const EventAttendee = sequelize.define('EventAttendee', {
    id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true
    },
    status: {
        type: DataTypes.ENUM('Going', 'Maybe', 'Not Going'),
        defaultValue: 'Going'
    }
}, {
    timestamps: true,
    tableName: 'event_attendees',
    indexes: [
        {
            unique: true,
            fields: ['user_id', 'event_id']
        }
    ]
});

module.exports = EventAttendee;
