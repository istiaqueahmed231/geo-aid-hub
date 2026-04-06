const mysql = require('mysql2');
require('dotenv').config();

const db = mysql.createConnection(process.env.DATABASE_URL);

db.connect((err) => {
    if (err) {
        console.error('❌ Database connection failed:', err.message);
        process.exit(1);
    }
    
    console.log('✅ Connected. Adding new Bangladesh shelters...');

    // We will add new locations first
    const newLocations = [
        ['Khulna Cyclone Center', 22.8456, 89.5403, 'Coastal'],
        ['Rajshahi Disaster Base', 24.3636, 88.6241, 'Rural'],
        ['Chittagong High-Ground', 22.3569, 91.7832, 'Hilly']
    ];

    let completed = 0;
    newLocations.forEach(loc => {
        db.query(`INSERT INTO Locations (AreaName, Latitude, Longitude, ZoneType) VALUES (?, ?, ?, ?)`, loc, (err, result) => {
            if (err) {
                console.error('Failed to add location:', err);
            } else {
                const locId = result.insertId;
                
                // Add shelter for this location
                let shelterName = '';
                let capacity = 0;
                if (loc[0] === 'Khulna Cyclone Center') { shelterName = 'Khulna Main Shelter'; capacity = 3000; }
                if (loc[0] === 'Rajshahi Disaster Base') { shelterName = 'Rajshahi Safe Zone'; capacity = 1500; }
                if (loc[0] === 'Chittagong High-Ground') { shelterName = 'Chittagong Hill Tracts Shelter'; capacity = 2500; }

                db.query(`INSERT INTO Shelters (ShelterName, LocationID, TotalCapacity, CurrentOccupancy, Status) VALUES (?, ?, ?, 0, 'Open')`, 
                [shelterName, locId, capacity], (err, res) => {
                    if (err) console.error('Failed to add shelter:', err);
                    else console.log(`Added Shelter: ${shelterName}`);
                    
                    completed++;
                    if (completed === newLocations.length) {
                        console.log('✅ Done adding dummy data.');
                        db.end();
                    }
                });
            }
        });
    });
});
