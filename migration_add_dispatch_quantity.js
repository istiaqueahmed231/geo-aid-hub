const mysql = require('mysql2');
require('dotenv').config();

const db = mysql.createConnection(process.env.DATABASE_URL);

db.connect((err) => {
    if (err) {
        console.error('Connection failed:', err.message);
        process.exit(1);
    }
    console.log('Connected to database.');
    
    const migrationSql = 'ALTER TABLE HelpRequests ADD COLUMN DispatchedQuantity INT DEFAULT NULL;';
    
    db.query(migrationSql, (err, results) => {
        if (err) {
            if (err.code === 'ER_DUP_COLUMN_NAME') {
                console.log('Column DispatchedQuantity already exists. Skipping migration.');
            } else {
                console.error('Error adding column DispatchedQuantity:', err);
                process.exit(1);
            }
        } else {
            console.log('Successfully added DispatchedQuantity column to HelpRequests table!');
        }
        db.end();
        process.exit(0);
    });
});
