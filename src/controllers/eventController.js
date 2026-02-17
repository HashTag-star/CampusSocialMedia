const { Event, User, EventAttendee } = require('../models');

// Create Event
exports.createEvent = async (req, res) => {
    try {
        const userId = req.user.id;
        const { title, description, location, date } = req.body;
        
        const user = await User.findByPk(userId);
        if (!user.university_id) return res.status(400).json({ message: 'User not affiliated with university' });

        const newEvent = await Event.create({
            host_id: userId,
            university_id: user.university_id,
            title,
            description,
            location,
            date
        });

        res.status(201).json(newEvent);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// List Campus Events
exports.listEvents = async (req, res) => {
    try {
        const userId = req.user.id;
        const user = await User.findByPk(userId);

        const events = await Event.findAll({
            where: { university_id: user.university_id },
            include: [{ model: User, as: 'Host', attributes: ['id', 'email', 'profile_data'] }],
            order: [['date', 'ASC']]
        });

        res.json(events);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// RSVP to Event
exports.rsvpEvent = async (req, res) => {
    try {
        const userId = req.user.id;
        const eventId = req.params.eventId;
        const { status } = req.body; // 'Going', 'maybe', 'not_going'

        const event = await Event.findByPk(eventId);
        if (!event) return res.status(404).json({ message: 'Event not found' });

        const [attendee, created] = await EventAttendee.findOrCreate({
            where: { user_id: userId, event_id: eventId },
            defaults: { status: status || 'Going' }
        });

        if (!created) {
            attendee.status = status;
            await attendee.save();
        }

        res.json({ message: 'RSVP updated', attendee });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};
