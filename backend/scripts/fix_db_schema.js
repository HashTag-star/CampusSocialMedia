const { sequelize } = require('../src/config/database');

async function fixSchema() {
    try {
        await sequelize.authenticate();
        console.log('Connection has been established successfully.');

        // Add interests column
        await sequelize.query(`
            ALTER TABLE "users" 
            ADD COLUMN IF NOT EXISTS "interests" JSONB DEFAULT '{}';
        `);
        console.log('Added "interests" column to "users" table.');

        // Add PostViews table if missing (sequelize sync usually handles this, but good to ensure)
        await sequelize.query(`
            CREATE TABLE IF NOT EXISTS "PostViews" (
                "id" UUID DEFAULT gen_random_uuid() PRIMARY KEY,
                "user_id" UUID REFERENCES "users" ("id") ON DELETE CASCADE,
                "post_id" UUID REFERENCES "posts" ("id") ON DELETE CASCADE,
                "viewer_id" UUID REFERENCES "users" ("id") ON DELETE CASCADE,
                "time_spent_ms" INTEGER DEFAULT 0,
                "createdAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                "updatedAt" TIMESTAMP WITH TIME ZONE DEFAULT NOW()
            );
        `);
        console.log('Ensured "PostViews" table exists.');

    } catch (error) {
        console.error('Unable to connect to the database:', error);
    } finally {
        await sequelize.close();
    }
}

fixSchema();
