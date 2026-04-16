const mysql = require('mysql2');
require('dotenv').config();

const dbURL = process.env.DATABASE_URL;
const cleanedURL = dbURL.split('?')[0];

const db = mysql.createConnection({
    uri: cleanedURL,
    ssl: { rejectUnauthorized: false }
});

db.connect((err) => {
    if (err) throw err;
    
    // Insert a few test admins
    const sql = `INSERT IGNORE INTO Admins (Email) VALUES ('admin@geoaid.com'), ('admin@test.com'), ('test@test.com')`;
    db.query(sql, (err) => {
        if (err) throw err;
        console.log('✅ Test Admin emails inserted into the database! (admin@geoaid.com, test@test.com)');
        process.exit();
    });
});
