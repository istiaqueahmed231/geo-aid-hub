const mysql = require('mysql2');
require('dotenv').config();

const db = mysql.createConnection(process.env.DATABASE_URL);

db.connect((err) => {
    if (err) {
        console.error('❌ Database connection failed:', err.message);
        process.exit(1);
    }
    
    console.log('✅ Connected. Adding new relatable Bangladesh resource locations...');

    const newLocations = [
        ['Dhaka Cantonment Supply Depot', 23.8182, 90.3956, 'Urban'],
        ['Barisal Port Storage Facility', 22.7010, 90.3535, 'Coastal'],
        ['Rangpur Central Warehouse', 25.7439, 89.2752, 'Rural'],
        ['Comilla Highway Relief Post', 23.4607, 91.1809, 'Urban']
    ];

    // First fetch CategoryIDs to ensure we map to valid foreign keys
    db.query(`SELECT CategoryID, CategoryName FROM ResourceCategories`, (err, categories) => {
        if (err || categories.length === 0) {
            console.error('Failed to fetch categories:', err);
            db.end();
            return;
        }

        let completedLocs = 0;
        newLocations.forEach(loc => {
            db.query(`INSERT INTO Locations (AreaName, Latitude, Longitude, ZoneType) VALUES (?, ?, ?, ?)`, loc, (err, result) => {
                if (err) {
                    console.error('Failed to add location:', err);
                } else {
                    const locId = result.insertId;
                    
                    // Add 2 random resources per location
                    for (let i = 0; i < 2; i++) {
                        // Pick a random category
                        const category = categories[Math.floor(Math.random() * categories.length)];
                        
                        // Pick random quantity
                        const qty = Math.floor(Math.random() * 500) + 50;
                        const status = qty > 100 ? 'Available' : 'Reserved';

                        db.query(`INSERT INTO Resources (CategoryID, CurrentLocationID, Quantity, Status) VALUES (?, ?, ?, ?)`, 
                        [category.CategoryID, locId, qty, status], (err, res) => {
                            if (err) console.error('Failed to add resource:', err);
                            else console.log(`Added Resource: ${qty}x ${category.CategoryName} at ${loc[0]}`);
                        });
                    }
                    
                    completedLocs++;
                    if (completedLocs === newLocations.length) {
                        setTimeout(() => {
                            console.log('✅ Done adding dummy resource data.');
                            db.end();
                        }, 500); // Wait shortly to ensure all async resource inserts are fired and hopefully done
                    }
                }
            });
        });
    });
});
