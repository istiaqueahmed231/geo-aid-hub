// 1. Import our tools
const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
require('dotenv').config(); // This loads your secret .env file

// 2. Set up the server
const app = express();
app.use(cors()); // Allows your frontend to talk to this backend
app.use(express.json()); // Allows us to read JSON data

app.use(express.static('public')); // Tells the server to host files from a folder named 'public'

// 3. Connect to the Aiven Database
const db = mysql.createConnection(process.env.DATABASE_URL);

db.connect((err) => {
    if (err) {
        console.error('❌ Database connection failed:', err.message);
    } else {
        console.log('✅ Successfully connected to the Aiven Cloud Database!');
    }
});

// 4. Create a simple test route
app.get('/', (req, res) => {
    res.send('The Disaster Hub API is running!');
});


// --- OUR NEW API ROUTE ---
app.get('/api/requests', (req, res) => {
    // This SQL query joins 3 tables together to get readable names instead of just ID numbers
    const sql = `
        SELECT r.RequestID, r.RequestorName, r.UrgencyScore, r.Status, c.CategoryName, l.AreaName
        FROM HelpRequests r
        JOIN ResourceCategories c ON r.CategoryID = c.CategoryID
        JOIN Locations l ON r.LocationID = l.LocationID
        ORDER BY r.UrgencyScore DESC;
    `;

    db.query(sql, (err, results) => {
        if (err) {
            console.error("Error fetching requests:", err);
            return res.status(500).json({ error: "Failed to fetch data" });
        }
        // Send the data back to the browser as JSON
        res.json(results);
    });
});

// --- RESOURCE LOG API ROUTE ---
app.get('/api/resources', (req, res) => {
    const sql = `
        SELECT r.ResourceID, c.CategoryName, c.UnitOfMeasure, l.AreaName as CurrentLocation, r.Quantity, r.Status
        FROM Resources r
        JOIN ResourceCategories c ON r.CategoryID = c.CategoryID
        JOIN Locations l ON r.CurrentLocationID = l.LocationID
        ORDER BY r.ResourceID ASC;
    `;

    db.query(sql, (err, results) => {
        if (err) {
            console.error("Error fetching resources:", err);
            return res.status(500).json({ error: "Failed to fetch resources" });
        }
        res.json(results);
    });
});
// -------------------------

// --- SHELTERS API ROUTE ---
app.get('/api/shelters', (req, res) => {
    const sql = `
        SELECT s.ShelterName, s.TotalCapacity, s.CurrentOccupancy, s.Status, l.AreaName, l.Latitude, l.Longitude, l.ZoneType
        FROM Shelters s
        JOIN Locations l ON s.LocationID = l.LocationID;
    `;

    db.query(sql, (err, results) => {
        if (err) {
            console.error("Error fetching shelters:", err);
            return res.status(500).json({ error: "Failed to fetch shelters" });
        }
        res.json(results);
    });
});
// -------------------------


// --- RECEIVE SOS FROM FLUTTER APP ---
app.post('/api/sos', (req, res) => {
    const { RequestorName, CategoryID, UrgencyScore, Latitude, Longitude } = req.body;

    // 1. First, save the new GPS location to the Locations table
    const insertLocationSql = `
        INSERT INTO Locations (AreaName, Latitude, Longitude, ZoneType) 
        VALUES ('Live SOS Location', ?, ?, 'Urban');
    `;

    db.query(insertLocationSql, [Latitude, Longitude], (err, locResult) => {
        if (err) return res.status(500).json({ error: "Failed to save location" });

        const newLocationId = locResult.insertId;

        // 2. Then, save the actual SOS request linked to that new location
        const insertRequestSql = `
            INSERT INTO HelpRequests (RequestorName, LocationID, CategoryID, UrgencyScore, Status) 
            VALUES (?, ?, ?, ?, 'Pending');
        `;

        db.query(insertRequestSql, [RequestorName, newLocationId, CategoryID, UrgencyScore], (err, reqResult) => {
            if (err) return res.status(500).json({ error: "Failed to save SOS request" });
            
            res.status(201).json({ message: "SOS Received successfully!" });
        });
    });
});
// ------------------------------------

// 5. Start the server
const PORT = 3000;
app.listen(PORT, () => {
    console.log(`🚀 Server is running on http://localhost:${PORT}`);
});