const { sequelize } = require('../config/database');
const User = require('./User');
const University = require('./University');
const Post = require('./Post');
const Like = require('./Like');
const Comment = require('./Comment');
const CommentLike = require('./CommentLike');
const Follow = require('./Follow');
const Course = require('./Course');
const Enrollment = require('./Enrollment');
const Event = require('./Event');
const EventAttendee = require('./EventAttendee');
const Space = require('./Space');
const Story = require('./Story');
const Notification = require('./Notification');
const Conversation = require('./Conversation');
const ConversationParticipant = require('./ConversationParticipant');
const Message = require('./Message');
const StoryView = require('./StoryView');
const PostView = require('./PostView'); // [NEW]
const Block = require('./Block');
const Report = require('./Report');

// Associations
University.hasMany(User, { foreignKey: 'university_id' });
User.belongsTo(University, { foreignKey: 'university_id' });

// ... (existing)

// PostView Associations [NEW]
User.hasMany(PostView, { foreignKey: 'viewer_id' });
PostView.belongsTo(User, { foreignKey: 'viewer_id', as: 'viewer' });

Post.hasMany(PostView, { foreignKey: 'post_id' });
PostView.belongsTo(Post, { foreignKey: 'post_id' });

// Block Associations
User.hasMany(Block, { foreignKey: 'blocker_id', as: 'blockedUsers' });
User.hasMany(Block, { foreignKey: 'blocked_id', as: 'blockedByUsers' });

// Report Associations
User.hasMany(Report, { foreignKey: 'reporter_id', as: 'reportsFiled' });

const models = {
    User,
    University,
    Post,
    Comment,
    Like,
    Follow,
    Event,
    Course,
    Enrollment,
    EventAttendee,
    Conversation,
    ConversationParticipant,
    Message,
    Notification,
    Story,
    StoryView,
    PostView,
    Block,
    Report,
    CommentLike, // Added missing CommentLike
    Space // Added missing Space
};

User.hasMany(Post, { foreignKey: 'user_id' });
Post.belongsTo(User, { foreignKey: 'user_id' });

University.hasMany(Post, { foreignKey: 'university_id' });
Post.belongsTo(University, { foreignKey: 'university_id' });

// Likes
User.hasMany(Like, { foreignKey: 'user_id' });
Like.belongsTo(User, { foreignKey: 'user_id' });

Post.hasMany(Like, { foreignKey: 'post_id' });
Like.belongsTo(Post, { foreignKey: 'post_id' });

// Comments
User.hasMany(Comment, { foreignKey: 'user_id' });
Comment.belongsTo(User, { foreignKey: 'user_id' });

Post.hasMany(Comment, { foreignKey: 'post_id' });
Comment.belongsTo(Post, { foreignKey: 'post_id' });

// Nested Comments (Replies)
Comment.hasMany(Comment, { as: 'Replies', foreignKey: 'parent_id' });
Comment.belongsTo(Comment, { as: 'Parent', foreignKey: 'parent_id' });

// Comment Likes
User.hasMany(CommentLike, { foreignKey: 'user_id' });
CommentLike.belongsTo(User, { foreignKey: 'user_id' });

Comment.hasMany(CommentLike, { foreignKey: 'comment_id' });
CommentLike.belongsTo(Comment, { foreignKey: 'comment_id' });

// Follows
User.belongsToMany(User, { as: 'Followers', through: Follow, foreignKey: 'following_id', otherKey: 'follower_id' });
User.belongsToMany(User, { as: 'Following', through: Follow, foreignKey: 'follower_id', otherKey: 'following_id' });

// Courses & Enrollments
University.hasMany(Course, { foreignKey: 'university_id' });
Course.belongsTo(University, { foreignKey: 'university_id' });

User.belongsToMany(Course, { through: Enrollment, foreignKey: 'user_id' });
Course.belongsToMany(User, { through: Enrollment, foreignKey: 'course_id' });

// Events & Attendees
University.hasMany(Event, { foreignKey: 'university_id' });
Event.belongsTo(University, { foreignKey: 'university_id' });

User.hasMany(Event, { foreignKey: 'host_id', as: 'HostedEvents' });
Event.belongsTo(User, { foreignKey: 'host_id', as: 'Host' });

User.belongsToMany(Event, { through: EventAttendee, foreignKey: 'user_id', as: 'AttendingEvents' });
Event.belongsToMany(User, { through: EventAttendee, foreignKey: 'event_id', as: 'Attendees' });

// Spaces
University.hasMany(Space, { foreignKey: 'university_id' });
Space.belongsTo(University, { foreignKey: 'university_id' });

User.hasMany(Space, { foreignKey: 'host_id' });
Space.belongsTo(User, { foreignKey: 'host_id', as: 'Host' });

// Stories
User.hasMany(Story, { foreignKey: 'user_id' });
Story.belongsTo(User, { foreignKey: 'user_id' });

// StoryView Associations
User.hasMany(StoryView, { foreignKey: 'viewer_id' });
StoryView.belongsTo(User, { foreignKey: 'viewer_id', as: 'viewer' });

Story.hasMany(StoryView, { foreignKey: 'story_id' });
StoryView.belongsTo(Story, { foreignKey: 'story_id' });

// Notifications
User.hasMany(Notification, { foreignKey: 'recipient_id', as: 'Notifications' });
Notification.belongsTo(User, { foreignKey: 'recipient_id', as: 'Recipient' });
Notification.belongsTo(User, { foreignKey: 'actor_id', as: 'Actor' });

// Conversations & Messages
Conversation.hasMany(ConversationParticipant, { foreignKey: 'conversation_id', as: 'Participants' });
ConversationParticipant.belongsTo(Conversation, { foreignKey: 'conversation_id' });
ConversationParticipant.belongsTo(User, { foreignKey: 'user_id' });
User.hasMany(ConversationParticipant, { foreignKey: 'user_id' });

Conversation.hasMany(Message, { foreignKey: 'conversation_id', as: 'Messages' });
Message.belongsTo(Conversation, { foreignKey: 'conversation_id' });
Message.belongsTo(User, { foreignKey: 'sender_id', as: 'Sender' });
User.hasMany(Message, { foreignKey: 'sender_id' });

module.exports = {
    sequelize,
    User,
    University,
    Post,
    Like,
    Comment,
    CommentLike,
    Follow,
    Course,
    Enrollment,
    Event,
    EventAttendee,
    Space,
    Story,
    Notification,
    Conversation,
    ConversationParticipant,
    Message,
    StoryView,
    PostView
};
