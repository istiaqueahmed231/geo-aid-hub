const mysql = require('mysql2/promise');
require('dotenv').config();

async function migrate() {
    const dbURL = process.env.DATABASE_URL;
    const cleanedURL = dbURL.split('?')[0];

    const db = await mysql.createConnection({
        uri: cleanedURL,
        ssl: { rejectUnauthorized: false }
    });

    console.log('--- Starting Migration: Add Dispatch Columns ---');

    try {
        // Run them one by one to avoid complete failure if one exists
        const queries = [
            "ALTER TABLE HelpRequests ADD COLUMN AssignedVolunteerID INT",
            "ALTER TABLE HelpRequests ADD COLUMN AssignedResourceID INT",
            "ALTER TABLE HelpRequests ADD COLUMN DispatchedAt TIMESTAMP NULL",
            "ALTER TABLE HelpRequests MODIFY COLUMN Status ENUM('Pending', 'Assigned', 'Dispatched', 'Fulfilled', 'Cancelled') DEFAULT 'Pending'"
        ];

        for (const sql of queries) {
            try {
                await db.query(sql);
                console.log(`✅ Success: ${sql.substring(0, 50)}...`);
            } catch (e) {
                if (e.code === 'ER_DUP_FIELDNAME') {
                    console.log(`ℹ️ Column already exists, skipping: ${sql.substring(0, 50)}...`);
                } else {
                    console.error(`❌ Error in query [${sql}]:`, e.message);
                }
            }
        }

    } catch (err) {
        console.error('❌ Migration failed:', err.message);
    } finally {
        await db.end();
        process.exit(0);
    }
}

migrate();
