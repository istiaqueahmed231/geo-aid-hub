const mysql = require('mysql2');
require('dotenv').config();

const db = mysql.createConnection(process.env.DATABASE_URL);

db.connect((err) => {
    if (err) {
        console.error('Connection failed:', err.message);
        process.exit(1);
    }
    
    db.query('DESCRIBE HelpRequests', (err, results) => {
        if (err) {
            console.error('Error describing HelpRequests:', err);
        } else {
            console.log('--- HelpRequests Table ---');
            console.log(JSON.stringify(results, null, 2));
        }
        
        db.query('DESCRIBE Locations', (err, results) => {
            if (err) {
                console.error('Error describing Locations:', err);
            } else {
                console.log('--- Locations Table ---');
                console.log(JSON.stringify(results, null, 2));
            }
            db.end();
            process.exit(0);
        });
    });
});
