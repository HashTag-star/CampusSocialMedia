const { sequelize, User } = require('./src/models');

const promoteUser = async () => {
    try {
        await sequelize.authenticate();
        console.log('Database connected.');

        const email = 'naseefhamza1@knust.edu';
        const user = await User.findOne({ where: { email } });

        if (!user) {
            console.error(`User with email ${email} not found.`);
            process.exit(1);
        }

        user.role = 'admin';
        await user.save();

        console.log(`✅ User ${user.email} is now an ADMIN.`);
    } catch (error) {
        console.error('Error:', error);
    } finally {
        await sequelize.close();
        process.exit();
    }
};

promoteUser();
