const { Course, User, Enrollment, University } = require('../models');

// List Courses (for user's university)
exports.listCourses = async (req, res) => {
    try {
        const userId = req.user.id;
        const user = await User.findByPk(userId);

        if (!user.university_id) {
            return res.status(400).json({ message: 'User has no university affiliated' });
        }

        const courses = await Course.findAll({
            where: { university_id: user.university_id },
            order: [['code', 'ASC']]
        });

        res.json(courses);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Join Course
exports.joinCourse = async (req, res) => {
    try {
        const userId = req.user.id;
        const courseId = req.params.courseId;
        const { role } = req.body; // Optional: 'Student', 'TA'

        const course = await Course.findByPk(courseId);
        if (!course) return res.status(404).json({ message: 'Course not found' });

        const [enrollment, created] = await Enrollment.findOrCreate({
            where: { user_id: userId, course_id: courseId },
            defaults: { role: role || 'Student' }
        });

        if (!created) {
            return res.status(400).json({ message: 'Already enrolled in this course' });
        }

        res.status(200).json({ message: 'Enrolled successfully', enrollment });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Get My Courses
exports.getMyCourses = async (req, res) => {
    try {
        const userId = req.user.id;
        const user = await User.findByPk(userId, {
            include: [{ model: Course, through: { attributes: ['role'] } }]
        });

        res.json(user.Courses);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};
