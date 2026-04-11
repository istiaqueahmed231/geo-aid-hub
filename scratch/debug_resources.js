require('dotenv').config();
const mysql = require('mysql2');
const dbURL = process.env.DATABASE_URL;
const cleanedURL = dbURL.split('?')[0];
const db = mysql.createConnection({ uri: cleanedURL, ssl: { rejectUnauthorized: false } });

db.connect();

const queries = [
    { name: 'Resources Table Count', sql: 'SELECT COUNT(*) as count FROM Resources' },
    { name: 'ResourceCategories Table Count', sql: 'SELECT COUNT(*) as count FROM ResourceCategories' },
    { name: 'Locations Table Count', sql: 'SELECT COUNT(*) as count FROM Locations' },
    { name: 'Sample Resources', sql: 'SELECT * FROM Resources LIMIT 5' },
    { name: 'Joined Resources (The API Query)', sql: `
        SELECT r.ResourceID, c.CategoryName, c.UnitOfMeasure, l.AreaName as CurrentLocation, l.Latitude, l.Longitude, r.Quantity, r.Status
        FROM Resources r
        JOIN ResourceCategories c ON r.CategoryID = c.CategoryID
        JOIN Locations l ON r.CurrentLocationID = l.LocationID
        LIMIT 5
    `}
];

async function runQueries() {
    for (const q of queries) {
        console.log(`\n=== ${q.name} ===`);
        try {
            const [results] = await db.promise().query(q.sql);
            console.table(results);
        } catch (err) {
            console.error(`Error in ${q.name}:`, err.message);
        }
    }
    db.end();
}

runQueries();
