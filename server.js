// 1. Import our tools
const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
require('dotenv').config(); // This loads your secret .env file

// 2. Set up the server
const app = express();
app.use(cors()); // Allows your frontend to talk to this backend
app.use(express.json()); // Allows us to read JSON data

app.use(express.static('public', { index: 'welcome.html' })); // Tells the server to host files from a folder named 'public' and load welcome.html by default

// 3. Connect to the Aiven Database
const dbURL = process.env.DATABASE_URL;
// Aiven requires SSL. We'll strip the ?ssl-mode=REQUIRED if present and add the ssl object manually for mysql2
const cleanedURL = dbURL.split('?')[0];

const db = mysql.createConnection({
    uri: cleanedURL,
    ssl: {
        rejectUnauthorized: false // Required for Aiven unless you have the CA cert locally
    }
});

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
    // Join with Volunteers and Resources to show who is helping and what was sent
    const sql = `
        SELECT 
            r.RequestID, r.RequestorName, r.UrgencyScore, r.Status, r.ShortMessage, 
            c.CategoryName, l.AreaName, l.Latitude, l.Longitude,
            v.Name AS DispatcherName, 
            rc.CategoryName AS DispatchedItemName,
            r.DispatchedQuantity
        FROM HelpRequests r
        JOIN ResourceCategories c ON r.CategoryID = c.CategoryID
        JOIN Locations l ON r.LocationID = l.LocationID
        LEFT JOIN Volunteers v ON r.AssignedVolunteerID = v.VolunteerID
        LEFT JOIN Resources res ON r.AssignedResourceID = res.ResourceID
        LEFT JOIN ResourceCategories rc ON res.CategoryID = rc.CategoryID
        ORDER BY FIELD(r.Status, 'Pending') DESC, r.UrgencyScore DESC;
    `;

    db.query(sql, (err, results) => {
        if (err) {
            console.error("Error fetching requests:", err);
            return res.status(500).json({ error: "Failed to fetch data" });
        }
        res.json(results);
    });
});


// --- RESOURCES API ROUTE ---
app.get('/api/resources', (req, res) => {
    const sql = `
        SELECT r.ResourceID, c.CategoryName, c.UnitOfMeasure, l.AreaName as CurrentLocation, l.Latitude, l.Longitude, r.Quantity, r.Status
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

app.get('/api/resource-categories', (req, res) => {
    db.query('SELECT CategoryID, CategoryName, UnitOfMeasure FROM ResourceCategories ORDER BY CategoryName', (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(results);
    });
});

app.get('/api/locations', (req, res) => {
    db.query("SELECT LocationID, AreaName FROM Locations WHERE AreaName != 'Live SOS Location' ORDER BY AreaName", (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(results);
    });
});

app.post('/api/resources', (req, res) => {
    const { categoryId, locationId, quantity } = req.body;
    const qty = parseInt(quantity);

    if (!categoryId || !locationId || isNaN(qty)) {
        return res.status(400).json({ error: "Missing or invalid fields" });
    }

    // Check if a resource of this category already exists at this location
    const checkSql = 'SELECT ResourceID FROM Resources WHERE CategoryID = ? AND CurrentLocationID = ? LIMIT 1';
    db.query(checkSql, [categoryId, locationId], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });

        if (results.length > 0) {
            // Update existing row
            const updateSql = "UPDATE Resources SET Quantity = Quantity + ?, Status = 'Available' WHERE ResourceID = ?";
            db.query(updateSql, [qty, results[0].ResourceID], (err) => {
                if (err) return res.status(500).json({ error: err.message });
                res.json({ message: "Resource quantity updated and status set to Available." });
            });
        } else {
            // Insert new row
            const insertSql = "INSERT INTO Resources (CategoryID, CurrentLocationID, Quantity, Status) VALUES (?, ?, ?, 'Available')";
            db.query(insertSql, [categoryId, locationId, qty], (err) => {
                if (err) return res.status(500).json({ error: err.message });
                res.status(201).json({ message: "New resource added successfully." });
            });
        }
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
    const { RequestorName, CategoryID, UrgencyScore, Latitude, Longitude, ShortMessage } = req.body;

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
            INSERT INTO HelpRequests (RequestorName, LocationID, CategoryID, UrgencyScore, Status, ShortMessage) 
            VALUES (?, ?, ?, ?, 'Pending', ?);
        `;

        db.query(insertRequestSql, [RequestorName, newLocationId, CategoryID, UrgencyScore, ShortMessage], (err, reqResult) => {
            if (err) return res.status(500).json({ error: "Failed to save SOS request" });
            
            res.status(201).json({ message: "SOS Received successfully!" });
        });
    });
});
// --- VOLUNTEER FLEET API ROUTE ---
app.get('/api/volunteers', (req, res) => {
    const sql = `
        SELECT VolunteerID, Name, Gender, Age, Location, Role, Status
        FROM Volunteers
        WHERE UID IS NOT NULL AND Email IS NOT NULL
        ORDER BY VolunteerID ASC;
    `;
    db.query(sql, (err, results) => {
        if (err) {
            console.error("Error fetching volunteers:", err);
            return res.status(500).json({ error: "Failed to fetch data" });
        }
        res.json(results);
    });
});

app.post('/api/volunteers', (req, res) => {
    const { uid, email, name, status, location, age, gender } = req.body;
    
    if (!uid || !email || !name) {
        return res.status(400).json({ error: "Missing required fields" });
    }

    const sql = `
        INSERT INTO Volunteers (Name, Email, UID, Gender, Age, Location, Role, Status) 
        VALUES (?, ?, ?, ?, ?, ?, 'General', ?)
    `;
    
    db.query(sql, [name, email, uid, gender || null, age || null, location || null, status || 'Available'], (err, result) => {
        if (err) {
            console.error('Error inserting volunteer:', err);
            return res.status(500).json({ error: 'Failed to create volunteer profile' });
        }
        res.status(201).json({ message: 'Volunteer created successfully', id: result.insertId });
    });
});
// --- GLOBAL STATS API ROUTE ---
app.get('/api/stats', (req, res) => {
    const sosSql = `SELECT COUNT(*) AS count FROM HelpRequests WHERE Status = 'Pending'`;
    const volSql = `SELECT COUNT(*) AS count FROM Volunteers WHERE Status = 'Active' AND UID IS NOT NULL AND Email IS NOT NULL`;

    db.query(sosSql, (err, sosResult) => {
        if (err) {
            console.error("SOS Stats Query Error:", err);
            return res.status(500).json({ error: "Failed to fetch SOS stats" });
        }
        db.query(volSql, (err, volResult) => {
            if (err) {
                console.error("Volunteer Stats Query Error:", err);
                return res.status(500).json({ error: "Failed to fetch Volunteer stats" });
            }
            res.json({
                pendingSOS: sosResult[0].count,
                activeVolunteers: volResult[0].count
            });
        });
    });
});
// --- GET CURRENT VOLUNTEER PROFILE BY FIREBASE UID ---
app.get('/api/me', (req, res) => {
    const { uid } = req.query;
    if (!uid) return res.status(400).json({ error: 'Missing uid parameter' });

    const sql = `
        SELECT VolunteerID, Name, Email, Role, Status, Location
        FROM Volunteers
        WHERE UID = ?
        LIMIT 1;
    `;
    db.query(sql, [uid], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        if (results.length === 0) return res.status(404).json({ error: 'Volunteer profile not found for this account.' });
        res.json(results[0]);
    });
});
// -------------------------------------------------------

// --- PROXIMITY APIS FOR DISPATCH ---

// Get nearest available resources for a specific category
app.get('/api/nearest-resources', (req, res) => {
    const { lat, lon, categoryId } = req.query;
    if (!lat || !lon || !categoryId) return res.status(400).json({ error: "Missing parameters" });

    const sql = `
        SELECT r.ResourceID, c.CategoryName, r.Quantity, l.AreaName, l.Latitude, l.Longitude,
        (6371 * acos(cos(radians(?)) * cos(radians(l.Latitude)) * cos(radians(l.Longitude) - radians(?)) + sin(radians(?)) * sin(radians(l.Latitude)))) AS distance
        FROM Resources r
        JOIN ResourceCategories c ON r.CategoryID = c.CategoryID
        JOIN Locations l ON r.CurrentLocationID = l.LocationID
        WHERE r.CategoryID = ? AND r.Quantity > 0 AND r.Status = 'Available'
        ORDER BY distance ASC
        LIMIT 5;
    `;

    db.query(sql, [lat, lon, lat, categoryId], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(results);
    });
});

// Get ALL available resources (any category), sorted by proximity
app.get('/api/available-resources', (req, res) => {
    const { lat, lon } = req.query;
    if (!lat || !lon) return res.status(400).json({ error: "Missing lat/lon parameters" });

    const sql = `
        SELECT r.ResourceID, c.CategoryName, c.UnitOfMeasure, r.Quantity, l.AreaName, l.Latitude, l.Longitude,
        (6371 * acos(
            cos(radians(?)) * cos(radians(l.Latitude)) * cos(radians(l.Longitude) - radians(?))
            + sin(radians(?)) * sin(radians(l.Latitude))
        )) AS distance
        FROM Resources r
        JOIN ResourceCategories c ON r.CategoryID = c.CategoryID
        JOIN Locations l ON r.CurrentLocationID = l.LocationID
        WHERE r.Quantity > 0 AND r.Status = 'Available'
        ORDER BY distance ASC;
    `;

    db.query(sql, [lat, lon, lat], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(results);
    });
});


// Get nearest available volunteers
app.get('/api/nearest-volunteers', (req, res) => {
    const { lat, lon } = req.query;
    // Note: Volunteers table currently has a 'Location' string, not lat/lon. 
    // For now, we'll just return available ones. In a real app we'd geocode their last known location.
    const sql = `
        SELECT VolunteerID, Name, Role, Location, Status
        FROM Volunteers
        WHERE Status = 'Available'
        LIMIT 10;
    `;

    db.query(sql, (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(results);
    });
});

app.post('/api/dispatch', (req, res) => {
    const { volunteerId, resourceId, requestId, quantity } = req.body;
    const dispatchQty = parseInt(quantity) || 1;

    if (!volunteerId || !resourceId || !requestId) {
        return res.status(400).json({ error: 'Missing required fields' });
    }

    // Use a simplified multi-step update for now
    const updateV = "UPDATE Volunteers SET Status = 'Active' WHERE VolunteerID = ?";
    const updateR = "UPDATE Resources SET Quantity = Quantity - ? WHERE ResourceID = ? AND Quantity >= ?";
    const updateReq = "UPDATE HelpRequests SET Status = 'Dispatched', AssignedVolunteerID = ?, AssignedResourceID = ?, DispatchedQuantity = ?, DispatchedAt = NOW() WHERE RequestID = ?";

    db.query(updateV, [volunteerId], (err) => {
        if (err) return res.status(500).json({ error: 'Volunteer update failed' });
        
        db.query(updateR, [dispatchQty, resourceId, dispatchQty], (err, result) => {
            if (err) return res.status(500).json({ error: 'Resource update failed' });
            if (result.affectedRows === 0) return res.status(400).json({ error: 'Insufficient resource quantity' });
            
            db.query(updateReq, [volunteerId, resourceId, dispatchQty, requestId], (err) => {
                if (err) return res.status(500).json({ error: 'Request update failed' });
                res.json({ message: `Dispatch successful! ${dispatchQty} units have been deployed.` });
            });
        });
    });
});


// 5. Start the server
const PORT = 3000;
app.listen(PORT, () => {
    console.log(`🚀 Server is running on http://localhost:${PORT}`);
});