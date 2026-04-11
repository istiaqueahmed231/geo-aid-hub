const mysql = require('mysql2');
require('dotenv').config();

const dbURL = process.env.DATABASE_URL;
const cleanedURL = dbURL.split('?')[0];

const db = mysql.createConnection({
    uri: cleanedURL,
    ssl: { rejectUnauthorized: false }
});

async function inspect() {
    const tables = ['ResourceCategories', 'HelpRequests'];
    for (const table of tables) {
        console.log(`\n--- DESCRIBE ${table} ---`);
        const [results] = await db.promise().query(`DESCRIBE ${table}`);
        console.log(JSON.stringify(results, null, 2));
    }
    process.exit(0);
}

inspect();
