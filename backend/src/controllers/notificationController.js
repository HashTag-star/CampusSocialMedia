const { Notification, User } = require('../models');

exports.getNotifications = async (req, res) => {
    try {
        const userId = req.user.id;
        const notifications = await Notification.findAll({
            where: { recipient_id: userId },
            include: [
                {
                    model: User,
                    as: 'Actor',
                    attributes: ['id', 'email', 'profile_data']
                }
            ],
            order: [['createdAt', 'DESC']],
            limit: 50
        });
        res.json(notifications);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

exports.markAsRead = async (req, res) => {
    try {
        const { id } = req.params;
        const notification = await Notification.findByPk(id);
        
        if (!notification) return res.status(404).json({ message: 'Notification not found' });
        if (notification.recipient_id !== req.user.id) return res.status(403).json({ message: 'Not authorized' });

        notification.is_read = true;
        await notification.save();
        
        res.json(notification);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

exports.markAllAsRead = async (req, res) => {
    try {
        await Notification.update(
            { is_read: true },
            { where: { recipient_id: req.user.id, is_read: false } }
        );
        res.json({ message: 'All marked as read' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Internal or Test Endpoint to create a suggestion
exports.createSuggestion = async (req, res) => {
    try {
        const userId = req.user.id;
        // Typically logic here to find best suggestion
        // For now, let's just create a dummy one if requested
        const { targetUserId } = req.body;
        
        await Notification.create({
            recipient_id: userId,
            actor_id: targetUserId, // User being suggested
            type: 'suggestion',
            message: 'Suggested for you based on your contacts'
        });
        
        res.json({ message: 'Suggestion created' });
    } catch (error) {
         console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};
