const mysql = require('mysql2');
require('dotenv').config();

const db = mysql.createConnection(process.env.DATABASE_URL);

db.connect((err) => {
    if (err) {
        console.error('❌ Connection failed:', err.message);
        process.exit(1);
    }
    console.log('✅ Connected to database.');

    const tables = ['Volunteers', 'HelpRequests', 'Resources', 'Shelters', 'Locations', 'ResourceCategories'];
    let completed = 0;

    tables.forEach(table => {
        db.query(`SELECT COUNT(*) AS count FROM ${table}`, (err, results) => {
            if (err) {
                console.error(`❌ Error counting ${table}:`, err.message);
            } else {
                console.log(`📊 Table ${table}: ${results[0].count} rows`);
            }
            completed++;
            if (completed === tables.length) {
                console.log('\n--- Sample Volunteers (UID is not null) ---');
                db.query('SELECT VolunteerID, Name, UID, Email FROM Volunteers WHERE UID IS NOT NULL LIMIT 5', (err, results) => {
                    console.log(results);
                    db.end();
                    process.exit(0);
                });
            }
        });
    });
});
