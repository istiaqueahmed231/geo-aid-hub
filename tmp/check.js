const mysql = require('mysql2');
require('dotenv').config();

const db = mysql.createConnection(process.env.DATABASE_URL);

db.connect((err) => {
    if (err) throw err;
    db.query(`SELECT l.LocationID, l.AreaName, l.Latitude, l.Longitude FROM Resources r JOIN Locations l ON r.CurrentLocationID = l.LocationID`, (err, res) => {
        if (err) throw err;
        console.log("Resource Locations:", res);
        db.end();
    });
});
