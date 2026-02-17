const { Op } = require('sequelize');
const { sequelize, Conversation, ConversationParticipant, Message, User, Notification } = require('../models');

// GET /conversations — list my conversations
exports.getConversations = async (req, res) => {
    try {
        const userId = req.user.id;

        // Find all conversation IDs where this user is a participant
        const myParticipations = await ConversationParticipant.findAll({
            where: { user_id: userId },
            attributes: ['conversation_id', 'last_read_at']
        });

        const conversationIds = myParticipations.map(p => p.conversation_id);
        if (conversationIds.length === 0) return res.json([]);

        // Build a map of last_read_at per conversation for unread counting
        const readMap = {};
        myParticipations.forEach(p => {
            readMap[p.conversation_id] = p.last_read_at;
        });

        // Fetch conversations with the other participant's info
        const conversations = await Conversation.findAll({
            where: { id: { [Op.in]: conversationIds } },
            include: [
                {
                    model: ConversationParticipant,
                    as: 'Participants',
                    include: [
                        {
                            model: User,
                            attributes: ['id', 'email', 'profile_data']
                        }
                    ]
                }
            ],
            order: [['last_message_at', 'DESC NULLS LAST']]
        });

        // Format response
        const result = await Promise.all(conversations.map(async (conv) => {
            const convoJson = conv.toJSON();
            // Filter out "me" to get the other participant
            const otherParticipant = convoJson.Participants.find(p => p.user_id !== userId);
            const lastRead = readMap[conv.id];

            // Count unread messages
            const unreadWhere = { conversation_id: conv.id, sender_id: { [Op.ne]: userId } };
            if (lastRead) {
                unreadWhere.createdAt = { [Op.gt]: lastRead };
            }
            const unreadCount = await Message.count({ where: unreadWhere });

            return {
                id: conv.id,
                lastMessageText: convoJson.last_message_text,
                lastMessageAt: convoJson.last_message_at,
                unreadCount,
                otherUser: otherParticipant ? otherParticipant.User : null,
            };
        }));

        res.json(result);
    } catch (error) {
        console.error('getConversations error:', error);
        res.status(500).json({ message: 'Server error' });
    }
};

// GET /conversations/:id/messages — paginated messages
exports.getMessages = async (req, res) => {
    try {
        const userId = req.user.id;
        const conversationId = req.params.id;
        const limit = parseInt(req.query.limit) || 50;
        const before = req.query.before; // cursor-based pagination

        // Verify user is a participant
        const participant = await ConversationParticipant.findOne({
            where: { conversation_id: conversationId, user_id: userId }
        });
        if (!participant) return res.status(403).json({ message: 'Not a participant' });

        const whereClause = { conversation_id: conversationId };
        if (before) {
            whereClause.createdAt = { [Op.lt]: new Date(before) };
        }

        const messages = await Message.findAll({
            where: whereClause,
            include: [
                { model: User, as: 'Sender', attributes: ['id', 'email', 'profile_data'] }
            ],
            order: [['createdAt', 'DESC']],
            limit
        });

        res.json(messages.reverse()); // Return in chronological order
    } catch (error) {
        console.error('getMessages error:', error);
        res.status(500).json({ message: 'Server error' });
    }
};

// POST /conversations — create or find existing 1-on-1 conversation
exports.createConversation = async (req, res) => {
    try {
        const userId = req.user.id;
        const { recipientId } = req.body;

        if (!recipientId) return res.status(400).json({ message: 'recipientId is required' });
        if (recipientId === userId) return res.status(400).json({ message: 'Cannot message yourself' });

        // Check recipient exists
        const recipient = await User.findByPk(recipientId, {
            attributes: ['id', 'email', 'profile_data']
        });
        if (!recipient) return res.status(404).json({ message: 'User not found' });

        // Check if a conversation already exists between these two users
        const myConvos = await ConversationParticipant.findAll({
            where: { user_id: userId },
            attributes: ['conversation_id']
        });
        const myConvoIds = myConvos.map(p => p.conversation_id);

        if (myConvoIds.length > 0) {
            const existingParticipant = await ConversationParticipant.findOne({
                where: {
                    conversation_id: { [Op.in]: myConvoIds },
                    user_id: recipientId
                }
            });

            if (existingParticipant) {
                // Conversation already exists, return it
                const existingConvo = await Conversation.findByPk(existingParticipant.conversation_id);
                return res.json({
                    id: existingConvo.id,
                    lastMessageText: existingConvo.last_message_text,
                    lastMessageAt: existingConvo.last_message_at,
                    otherUser: recipient.toJSON(),
                    isNew: false
                });
            }
        }

        // Create new conversation
        const conversation = await Conversation.create({});

        // Add both participants
        await ConversationParticipant.bulkCreate([
            { conversation_id: conversation.id, user_id: userId },
            { conversation_id: conversation.id, user_id: recipientId }
        ]);

        res.status(201).json({
            id: conversation.id,
            lastMessageText: null,
            lastMessageAt: null,
            otherUser: recipient.toJSON(),
            isNew: true
        });
    } catch (error) {
        console.error('createConversation error:', error);
        res.status(500).json({ message: 'Server error' });
    }
};

// POST /conversations/:id/messages — send a message
exports.sendMessage = async (req, res) => {
    try {
        const userId = req.user.id;
        const conversationId = req.params.id;
        const { content, media_url } = req.body;

        if (!content && !media_url) return res.status(400).json({ message: 'Message content is required' });

        // Verify user is a participant
        const participant = await ConversationParticipant.findOne({
            where: { conversation_id: conversationId, user_id: userId }
        });
        if (!participant) return res.status(403).json({ message: 'Not a participant' });

        // Create message
        const message = await Message.create({
            conversation_id: conversationId,
            sender_id: userId,
            content: content || '',
            media_url: media_url || null
        });

        // Update conversation preview
        await Conversation.update(
            {
                last_message_text: content ? content.substring(0, 255) : '📷 Media',
                last_message_at: new Date()
            },
            { where: { id: conversationId } }
        );

        // Mark as read for the sender
        await ConversationParticipant.update(
            { last_read_at: new Date() },
            { where: { conversation_id: conversationId, user_id: userId } }
        );

        // Create notification for the other participant(s)
        const otherParticipants = await ConversationParticipant.findAll({
            where: { conversation_id: conversationId, user_id: { [Op.ne]: userId } }
        });

        const sender = await User.findByPk(userId, { attributes: ['id', 'email', 'profile_data'] });
        const senderName = sender?.profile_data?.name || sender?.email?.split('@')[0] || 'Someone';

        for (const other of otherParticipants) {
            await Notification.create({
                recipient_id: other.user_id,
                actor_id: userId,
                type: 'message',
                entity_id: conversationId,
                message: `${senderName} sent you a message`
            });
        }

        // Fetch full message with Sender
        const fullMessage = await Message.findByPk(message.id, {
            include: [
                { model: User, as: 'Sender', attributes: ['id', 'email', 'profile_data'] }
            ]
        });

        // Socket.io: Emit new message
        const io = req.app.get('io');
        if (io) {
            io.to(`conversation_${conversationId}`).emit('new_message', fullMessage);
        }

        res.status(201).json(fullMessage);
    } catch (error) {
        console.error('sendMessage error:', error);
        res.status(500).json({ message: 'Server error' });
    }
};

// PATCH /conversations/:id/read — mark conversation as read
exports.markAsRead = async (req, res) => {
    try {
        const userId = req.user.id;
        const conversationId = req.params.id;

        await ConversationParticipant.update(
            { last_read_at: new Date() },
            { where: { conversation_id: conversationId, user_id: userId } }
        );

        // Socket.io: Emit read receipt
        const io = req.app.get('io');
        if (io) {
            io.to(`conversation_${conversationId}`).emit('message_read', {
                conversationId,
                userId,
                readAt: new Date()
            });
        }

        res.json({ message: 'Marked as read' });
    } catch (error) {
        console.error('markAsRead error:', error);
        res.status(500).json({ message: 'Server error' });
    }
};
