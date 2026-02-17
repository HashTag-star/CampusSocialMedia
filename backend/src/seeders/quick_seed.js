require('dotenv').config();
const { Sequelize, DataTypes } = require('sequelize');
const bcrypt = require('bcryptjs');

const sequelize = new Sequelize(process.env.DATABASE_URL, {
    dialect: 'postgres',
    logging: console.log,
    dialectOptions: {
        ssl: {
            require: true,
            rejectUnauthorized: false
        }
    }
});

const seed = async () => {
    try {
        await sequelize.authenticate();
        console.log('Connected to DB');

        const University = sequelize.define('University', {
            id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
            name: { type: DataTypes.STRING, allowNull: false },
            domain: { type: DataTypes.STRING, allowNull: false, unique: true },
            logo_url: { type: DataTypes.STRING }
        }, { timestamps: true, tableName: 'universities' });

        const User = sequelize.define('User', {
            id: { type: DataTypes.UUID, defaultValue: DataTypes.UUIDV4, primaryKey: true },
            email: { type: DataTypes.STRING, allowNull: false, unique: true },
            password_hash: { type: DataTypes.STRING, allowNull: false },
            university_id: { type: DataTypes.UUID },
            profile_data: { type: DataTypes.JSONB, defaultValue: {} }
        }, { timestamps: true, tableName: 'users' });

        // Sync models (create tables if missing)
        await sequelize.sync(); 

        // 1. Create University
        const [stanford] = await University.findOrCreate({
            where: { domain: 'stanford.edu' },
            defaults: {
                name: 'Stanford University',
                domain: 'stanford.edu',
                logo_url: 'https://identity.stanford.edu/wp-content/uploads/sites/3/2020/06/block-s-right.png'
            }
        });
        console.log('University ID:', stanford.id);

        // 2. Create User
        const hashedPassword = await bcrypt.hash('password123', 10);
        const [user, created] = await User.findOrCreate({
            where: { email: 'userA@stanford.edu' },
            defaults: {
                email: 'userA@stanford.edu',
                password_hash: hashedPassword,
                university_id: stanford.id,
                profile_data: {
                    name: 'Alice Student',
                    bio: 'CS Major @ Stanford',
                    avatar_url: 'https://i.pravatar.cc/150?u=userA',
                    interests: ['coding', 'music']
                }
            }
        });
        
        console.log(created ? 'User created!' : 'User already exists');
        console.log('User ID:', user.id);

        process.exit(0);
    } catch (error) {
        console.error('Seed Error:', error);
        process.exit(1);
    }
};

seed();
