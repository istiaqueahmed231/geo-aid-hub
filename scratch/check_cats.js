const mysql = require('mysql2');
require('dotenv').config();

const dbURL = process.env.DATABASE_URL;
const cleanedURL = dbURL.split('?')[0];

const db = mysql.createConnection({
    uri: cleanedURL,
    ssl: { rejectUnauthorized: false }
});

db.connect((err) => {
    if (err) { console.error('Connection failed:', err.message); process.exit(1); }
    
    db.query('SELECT * FROM ResourceCategories', (err, results) => {
        if (err) { console.error('Error:', err); }
        else { console.log('--- ResourceCategories ---'); console.log(results); }
        
        db.query("SHOW CREATE TABLE HelpRequests", (err, res) => {
            console.log('--- HelpRequests Table ---');
            console.log(res);
            db.end();
            process.exit(0);
        });
    });
});
