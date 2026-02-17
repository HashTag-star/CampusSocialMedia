const { University, sequelize } = require('../models');

const seed = async () => {
    try {
        await sequelize.authenticate();
        await sequelize.sync({ force: false });

        const universities = [
            {
                name: 'Stanford University',
                domain: 'stanford.edu',
                logo_url: 'https://identity.stanford.edu/wp-content/uploads/sites/3/2020/06/block-s-right.png'
            },
            {
                name: 'Massachusetts Institute of Technology',
                domain: 'mit.edu',
                logo_url: 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0c/MIT_logo.svg/1024px-MIT_logo.svg.png'
            }
        ];

        for (const uni of universities) {
            const [university] = await University.findOrCreate({
                where: { domain: uni.domain },
                defaults: uni
            });

            // Seed Courses for University
            const courses = [
                { code: 'CS101', name: 'Intro to CS', semester: 'Fall 2026' },
                { code: 'ECON101', name: 'Principles of Economics', semester: 'Fall 2026' }
            ];

            const { Course } = require('../models');
            for (const course of courses) {
                await Course.findOrCreate({
                    where: { university_id: university.id, code: course.code },
                    defaults: { ...course, university_id: university.id }
                });
            }
        }

        // Seed Users
        const { User } = require('../models');
        const bcrypt = require('bcryptjs');

        const stanford = await University.findOne({ where: { domain: 'stanford.edu' } });
        const hashedPassword = await bcrypt.hash('password123', 10);

        const users = [
            {
                email: 'userA@stanford.edu',
                password_hash: hashedPassword,
                university_id: stanford.id,
                profile_data: {
                    name: 'Alice Student',
                    bio: 'CS Major @ Stanford',
                    avatar_url: 'https://i.pravatar.cc/150?u=userA',
                    interests: ['coding', 'music']
                }
            },
            {
                email: 'userB@stanford.edu',
                password_hash: hashedPassword,
                university_id: stanford.id,
                profile_data: {
                    name: 'Bob Monitor',
                    bio: 'Econ Major, loves data',
                    avatar_url: 'https://i.pravatar.cc/150?u=userB',
                    interests: ['economics', 'startups']
                }
            }
        ];

        for (const u of users) {
            await User.findOrCreate({
                where: { email: u.email },
                defaults: u
            });
        }

        console.log('Universities seeded successfully');
        process.exit(0);
    } catch (error) {
        console.error('Seeding failed:', error);
        process.exit(1);
    }
};

seed();
