require('dotenv').config();
const mysql = require('mysql2');
const dbURL = process.env.DATABASE_URL;
const cleanedURL = dbURL.split('?')[0];
const db = mysql.createConnection({ uri: cleanedURL, ssl: { rejectUnauthorized: false } });

db.connect();
const tables = ['HelpRequests', 'Volunteers', 'Resources', 'ResourceCategories'];
tables.forEach(table => {
    db.query(`DESCRIBE ${table}`, (err, results) => {
        if (err) console.error(`Error describing ${table}:`, err);
        else {
            console.log(`--- Table: ${table} ---`);
            console.table(results.map(r => ({ Field: r.Field, Type: r.Type })));
        }
    });
});
setTimeout(() => db.end(), 5000);
