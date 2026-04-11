const mysql = require('mysql2');
require('dotenv').config();

const dbURL = process.env.DATABASE_URL;
const cleanedURL = dbURL.split('?')[0];

const db = mysql.createConnection({
    uri: cleanedURL,
    ssl: { rejectUnauthorized: false }
});

db.query('SELECT Name, Location FROM Volunteers LIMIT 5', (err, results) => {
    if (err) {
        console.error(err);
        process.exit(1);
    }
    console.log(JSON.stringify(results, null, 2));
    process.exit(0);
});
