const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
const http = require('http'); // Node.js http module
const { Server } = require('socket.io'); // Socket.io
require('dotenv').config(); 

// 2. Set up the server
const app = express();
const server = http.createServer(app); // Wrap express with http
const io = new Server(server, {
    cors: {
        origin: "*", // Adjust this in production for security
        methods: ["GET", "POST"]
    }
});

app.use(cors()); 
app.use(express.json()); 

// Socket.io Connection logic
io.on('connection', (socket) => {
    console.log('📡 A dispatcher/client connected:', socket.id);
    
    // Join a specific request room for chat & live updates
    socket.on('join_request', (requestId) => {
        socket.join(`request_${requestId}`);
        console.log(`📡 Client joined room: request_${requestId}`);
    });

    // Handle incoming chat messages
    socket.on('send_message', (data) => {
        // data: { requestId, senderRole, senderId, text }
        const sql = `INSERT INTO Messages (RequestID, SenderRole, SenderID, MessageText) VALUES (?, ?, ?, ?)`;
        db.query(sql, [data.requestId, data.senderRole, data.senderId, data.text], (err, result) => {
            if (err) {
                console.error("Failed to save message:", err.message);
                return;
            }
            // Emit to everyone in the room
            io.to(`request_${data.requestId}`).emit('new_message', {
                MessageID: result.insertId,
                RequestID: data.requestId,
                SenderRole: data.senderRole,
                SenderID: data.senderId,
                MessageText: data.text,
                SentAt: new Date()
            });
        });
    });

    socket.on('disconnect', () => {
        console.log('📡 Client disconnected:', socket.id);
    });
});

app.use(express.static('public', { index: 'welcome.html' })); 

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

        // --- Auto-Migrations for New Features ---
        const migrations = [
            `CREATE TABLE IF NOT EXISTS Admins (
                AdminID INT AUTO_INCREMENT PRIMARY KEY,
                Email VARCHAR(255) NOT NULL UNIQUE,
                AddedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )`,
            `CREATE TABLE IF NOT EXISTS Messages (
                MessageID INT AUTO_INCREMENT PRIMARY KEY,
                RequestID INT NOT NULL,
                SenderRole ENUM('Volunteer', 'Victim', 'Admin') NOT NULL,
                SenderID VARCHAR(255) NOT NULL,
                MessageText TEXT NOT NULL,
                SentAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )`
        ];

        migrations.forEach(sql => {
            db.query(sql, (err) => {
                if (err) console.error("Migration failed:", err.message);
            });
        });

        db.query(`ALTER TABLE Volunteers ADD COLUMN Latitude DOUBLE, ADD COLUMN Longitude DOUBLE`, (err) => {
            if (err && err.code !== 'ER_DUP_FIELDNAME') {
                console.error("Alter Volunteers failed:", err.message);
            }
        });
        // ----------------------------------------
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
            
            // --- SOCKET.IO EMISSION ---
            // Notify all connected dashboards about the new emergency
            io.emit('new_sos', {
                RequestID: reqResult.insertId,
                RequestorName,
                CategoryID,
                UrgencyScore,
                ShortMessage,
                Latitude,
                Longitude,
                Status: 'Pending',
                CreatedAt: new Date()
            });
            // ---------------------------

            res.status(201).json({ message: "SOS Received successfully!", requestId: reqResult.insertId });
        });
    });
});
// --- VOLUNTEER FLEET API ROUTE ---
app.get('/api/volunteers', (req, res) => {
    const sql = `
        SELECT VolunteerID, Name, Gender, Age, Location, Latitude, Longitude, Role, Status
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

// --- GET SPECIFIC REQUEST (For Tracking Web/App) ---
app.get('/api/requests/:requestId', (req, res) => {
    const { requestId } = req.params;
    const sql = `
        SELECT r.*, v.Name AS VolunteerName, v.Latitude AS VolLat, v.Longitude AS VolLon,
        c.CategoryName AS DispatchedCategoryName, c.UnitOfMeasure,
        l.Latitude, l.Longitude
        FROM HelpRequests r 
        LEFT JOIN Volunteers v ON r.AssignedVolunteerID = v.VolunteerID 
        LEFT JOIN Resources rsc ON r.AssignedResourceID = rsc.ResourceID
        LEFT JOIN ResourceCategories c ON rsc.CategoryID = c.CategoryID
        LEFT JOIN Locations l ON r.LocationID = l.LocationID
        WHERE r.RequestID = ?
    `;
    db.query(sql, [requestId], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        if (results.length === 0) return res.status(404).json({ error: 'Not found' });
        res.json(results[0]);
    });
});

// --- NEW CHAT/MESSAGES ROUTE ---
app.get('/api/messages/:requestId', (req, res) => {
    const { requestId } = req.params;
    const sql = `SELECT * FROM Messages WHERE RequestID = ? ORDER BY SentAt ASC`;
    db.query(sql, [requestId], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(results);
    });
});

app.post('/api/messages', (req, res) => {
    const { requestId, senderRole, senderId, text } = req.body;
    const sql = `INSERT INTO Messages (RequestID, SenderRole, SenderID, MessageText) VALUES (?, ?, ?, ?)`;
    db.query(sql, [requestId, senderRole, senderId, text], (err, result) => {
        if (err) return res.status(500).json({ error: err.message });
        
        // Also emit via socket.io for the web app
        io.to(`request_${requestId}`).emit('new_message', {
            MessageID: result.insertId,
            RequestID: requestId,
            SenderRole: senderRole,
            SenderID: senderId,
            MessageText: text,
            SentAt: new Date()
        });

        res.status(201).json({ success: true });
    });
});

// --- ADMIN VERIFY ROUTE ---
app.get('/api/admin/verify', (req, res) => {
    const { email } = req.query;
    if (!email) return res.status(400).json({ error: "Missing email parameter" });
    
    // We check if this email exists in the Admins table
    const sql = `SELECT AdminID FROM Admins WHERE Email = ? LIMIT 1`;
    db.query(sql, [email], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        if (results.length > 0) {
            res.json({ isAdmin: true });
        } else {
            res.json({ isAdmin: false });
        }
    });
});

// --- VOLUNTEER LOCATION UPDATE ---
app.post('/api/volunteer/location', (req, res) => {
    const { uid, latitude, longitude, status } = req.body;
    if (!uid) return res.status(400).json({ error: "Missing uid" });
    
    // Update location and optionally status (e.g. 'Available')
    let sql = `UPDATE Volunteers SET Latitude = ?, Longitude = ?`;
    let params = [latitude, longitude];
    
    if (status) {
        sql += `, Status = ?`;
        params.push(status);
    }
    sql += ` WHERE UID = ?`;
    params.push(uid);

    db.query(sql, params, (err) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json({ message: "Location updated" });
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
    const sosSql = `SELECT Status, COUNT(*) AS count FROM HelpRequests GROUP BY Status`;
    const volSql = `SELECT COUNT(*) AS count FROM Volunteers WHERE Status = 'Available' AND UID IS NOT NULL AND Email IS NOT NULL`;
    const stockSql = `SELECT COUNT(*) AS count FROM Resources WHERE Quantity < 50 AND Status = 'Available'`;

    db.query(sosSql, (err, sosResults) => {
        if (err) return res.status(500).json({ error: err.message });
        
        db.query(volSql, (err, volResult) => {
            if (err) return res.status(500).json({ error: err.message });
            
            db.query(stockSql, (err, stockResult) => {
                if (err) return res.status(500).json({ error: err.message });

                const stats = {
                    pending: 0,
                    dispatched: 0,
                    volunteers: volResult[0].count,
                    lowStockCount: stockResult[0].count
                };

                sosResults.forEach(r => {
                    if (r.Status === 'Pending') stats.pending = r.count;
                    if (r.Status === 'Dispatched') stats.dispatched = r.count;
                });

                res.json(stats);
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

// --- PROXIMITY & SKILL APIS FOR DISPATCH ---

// Mapping SOS Categories to Recommended Volunteer Roles
const ROLE_MAPPING = {
    1: ['Medical Aid', 'First Responder'],         // Medical Kits
    2: ['Logistics', 'Supply Coordinator'],       // Drinking Water
    3: ['Logistics', 'Supply Coordinator'],       // Dry Food Rations
    4: ['Rescue Driver', 'First Responder']        // Rescue Boats
};

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

// Get available volunteers (with skill prioritization)
app.get('/api/nearest-volunteers', (req, res) => {
    const { categoryId } = req.query;
    
    const sql = `
        SELECT VolunteerID, Name, Role, Location, Status
        FROM Volunteers
        WHERE Status = 'Available'
        ORDER BY VolunteerID ASC;
    `;

    db.query(sql, (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        
        // Add recommendation flag based on category mapping
        const recommendedRoles = ROLE_MAPPING[categoryId] || [];
        const enrichedResults = results.map(v => ({
            ...v,
            isRecommended: recommendedRoles.includes(v.Role)
        }));

        // Sort by recommendation first
        enrichedResults.sort((a, b) => (b.isRecommended === a.isRecommended) ? 0 : b.isRecommended ? 1 : -1);

        res.json(enrichedResults);
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
    let sql = `
        SELECT VolunteerID, Name, Role, Location, Latitude, Longitude, Status
        FROM Volunteers
        WHERE Status = 'Available'
    `;
    
    if (lat && lon) {
        sql = `
            SELECT VolunteerID, Name, Role, Location, Latitude, Longitude, Status,
            (6371 * acos(
                cos(radians(?)) * cos(radians(Latitude)) * cos(radians(Longitude) - radians(?))
                + sin(radians(?)) * sin(radians(Latitude))
            )) AS distance
            FROM Volunteers
            WHERE Status = 'Available' AND Latitude IS NOT NULL AND Longitude IS NOT NULL
            ORDER BY distance ASC
            LIMIT 10;
        `;
        db.query(sql, [lat, lon, lat], (err, results) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json(results);
        });
    } else {
        db.query(sql + ' LIMIT 10', (err, results) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json(results);
        });
    }
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
                
                // Notify via Socket.IO
                io.emit('dispatch_assigned', {
                    RequestID: requestId,
                    VolunteerID: volunteerId,
                    ResourceID: resourceId,
                    DispatchedQuantity: dispatchQty,
                    DispatchedAt: new Date()
                });
                
                res.json({ message: `Dispatch successful! ${dispatchQty} units have been deployed.` });
            });
        });
    });
});


// 5. Start the server
const PORT = 3000;
server.listen(PORT, () => {
    console.log(`🚀 Real-time Command Server is running on http://localhost:${PORT}`);
});