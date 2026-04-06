require('dotenv').config();
const mysql = require('mysql2');

const db = mysql.createConnection(process.env.DATABASE_URL);

db.connect((err) => {
    if (err) throw err;
    db.query('ALTER TABLE Volunteers ADD COLUMN Email VARCHAR(255) UNIQUE AFTER Name, ADD COLUMN UID VARCHAR(128) UNIQUE AFTER Email', (err, results) => {
        if (err) throw err;
        console.log("Table altered successfully:", results);
        process.exit(0);
    });
});
