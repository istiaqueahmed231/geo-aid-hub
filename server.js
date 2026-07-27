const express = require("express");
const mysql = require("mysql2");
const cors = require("cors");
const http = require("http"); // Node.js http module
const { Server } = require("socket.io"); // Socket.io
require("dotenv").config();
const admin = require("firebase-admin");

// Try initializing Firebase Admin
// On Render (production): set the FIREBASE_SERVICE_ACCOUNT env variable to the full JSON string of serviceAccountKey.json
// Locally: falls back to reading the file directly
try {
  let serviceAccount;
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    console.log("✅ Firebase Admin: loading credentials from env variable.");
  } else {
    serviceAccount = require("./serviceAccountKey.json");
    console.log("✅ Firebase Admin: loading credentials from local file.");
  }
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  console.log("✅ Firebase Admin initialized for Push Notifications.");
} catch (e) {
  console.error("⚠️ Push notifications disabled. Reason:", e.message);
}

// 2. Set up the server
const app = express();
const server = http.createServer(app); // Wrap express with http
const io = new Server(server, {
  cors: {
    origin: "*", // Adjust this in production for security
    methods: ["GET", "POST"],
  },
});

app.use(cors());
app.use(express.json());

// Socket.io Connection logic
io.on("connection", (socket) => {
  console.log("📡 A dispatcher/client connected:", socket.id);

  // Join a specific request room for chat & live updates
  socket.on("join_request", (requestId) => {
    socket.join(`request_${requestId}`);
    console.log(`📡 Client joined room: request_${requestId}`);
  });

  // Handle incoming chat messages
  socket.on("send_message", (data) => {
    // data: { requestId, senderRole, senderId, text }
    const sql = `INSERT INTO Messages (RequestID, SenderRole, SenderID, MessageText) VALUES (?, ?, ?, ?)`;
    db.query(
      sql,
      [data.requestId, data.senderRole, data.senderId, data.text],
      (err, result) => {
        if (err) {
          console.error("Failed to save message:", err.message);
          return;
        }
        // Emit to everyone in the room
        io.to(`request_${data.requestId}`).emit("new_message", {
          MessageID: result.insertId,
          RequestID: data.requestId,
          SenderRole: data.senderRole,
          SenderID: data.senderId,
          MessageText: data.text,
          SentAt: new Date(),
        });
      },
    );
  });

  socket.on("disconnect", () => {
    console.log("📡 Client disconnected:", socket.id);
  });
});

app.use(express.static("public", { index: "welcome.html" }));

// 3. Connect to the Aiven Database
const dbURL = process.env.DATABASE_URL;
// Aiven requires SSL. We'll strip the ?ssl-mode=REQUIRED if present and add the ssl object manually for mysql2
const cleanedURL = dbURL.split("?")[0];

const db = mysql.createConnection({
  uri: cleanedURL,
  ssl: {
    rejectUnauthorized: false, // Required for Aiven unless you have the CA cert locally
  },
});

db.connect((err) => {
  if (err) {
    console.error("❌ Database connection failed:", err.message);
  } else {
    console.log("✅ Successfully connected to the Aiven Cloud Database!");

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
            )`,
      `CREATE TABLE IF NOT EXISTS Feedback (
                FeedbackID INT AUTO_INCREMENT PRIMARY KEY,
                RequestID INT NOT NULL UNIQUE,
                IsSafe TINYINT(1) DEFAULT 1,
                Rating INT DEFAULT 5,
                FeedbackNote TEXT,
                SubmittedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )`,
      `CREATE TABLE IF NOT EXISTS Victims (
                VictimID INT AUTO_INCREMENT PRIMARY KEY,
                AuthUID VARCHAR(128) NOT NULL UNIQUE,
                FullName VARCHAR(255) NOT NULL,
                PhoneNumber VARCHAR(20),
                HomeAddress TEXT,
                Age INT,
                Gender VARCHAR(50),
                HouseholdCount INT DEFAULT 1,
                HasVulnerableDependents TINYINT(1) DEFAULT 0,
                MobilityStatus ENUM('Fully Mobile', 'Wheelchair', 'Bedbound', 'Requires Assistance') DEFAULT 'Fully Mobile',
                MedicalDependencies TEXT,
                PrimaryLanguage VARCHAR(100) DEFAULT 'Local',
                PetCount INT DEFAULT 0,
                EmergencyContactName VARCHAR(255),
                EmergencyContactPhone VARCHAR(20),
                CreatedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )`,
    ];

    migrations.forEach((sql) => {
      db.query(sql, (err) => {
        if (err) console.error("Migration failed:", err.message);
      });
    });

    db.query(
      `INSERT IGNORE INTO ResourceCategories (CategoryID, CategoryName, UnitOfMeasure) VALUES 
       (1, 'Emergency Medical Kits', 'kits'),
       (2, 'Drinking Water', 'liters'),
       (3, 'Dry Food Rations', 'packs'),
       (4, 'Rescue Boats', 'boats')`,
      (err) => {
        if (err) console.error("ResourceCategories backfill failed:", err.message);
      }
    );

    db.query(
      `ALTER TABLE HelpRequests ADD COLUMN VictimID INT NULL`,
      (err) => {
        if (err && err.code !== "ER_DUP_FIELDNAME") {
          console.error("Alter HelpRequests VictimID failed:", err.message);
        }
      },
    );

    db.query(
      `ALTER TABLE HelpRequests ADD COLUMN ResolvedAt TIMESTAMP NULL`,
      (err) => {
        if (err && err.code !== "ER_DUP_FIELDNAME") {
          console.error("Alter HelpRequests ResolvedAt failed:", err.message);
        }
      },
    );

    db.query(
      `ALTER TABLE Volunteers ADD COLUMN Latitude DOUBLE, ADD COLUMN Longitude DOUBLE`,
      (err) => {
        if (err && err.code !== "ER_DUP_FIELDNAME") {
          console.error("Alter Volunteers failed:", err.message);
        }
      },
    );
    db.query(
      `ALTER TABLE HelpRequests ADD COLUMN FCMToken VARCHAR(255)`,
      (err) => {
        if (err && err.code !== "ER_DUP_FIELDNAME") {
          console.error("Alter HelpRequests failed:", err.message);
        }
      },
    );
    db.query(
      `ALTER TABLE HelpRequests ADD COLUMN CompletedAt TIMESTAMP NULL`,
      (err) => {
        if (err && err.code !== "ER_DUP_FIELDNAME") {
          console.error("Alter HelpRequests CompletedAt failed:", err.message);
        }
      },
    );
    db.query(
      `ALTER TABLE HelpRequests MODIFY COLUMN Status VARCHAR(50) DEFAULT 'Pending'`,
      (err) => {
        if (err) {
          console.error("Modify HelpRequests Status column failed:", err.message);
        }
      },
    );
    db.query(
      `ALTER TABLE Volunteers ADD COLUMN FCMToken VARCHAR(255)`,
      (err) => {
        if (err && err.code !== "ER_DUP_FIELDNAME") {
          console.error("Alter Volunteers FCMToken failed:", err.message);
        }
      },
    );
    db.query(
      `ALTER TABLE Volunteers ADD COLUMN PhoneNumber VARCHAR(50), ADD COLUMN HomeAddress TEXT, ADD COLUMN IsVerified TINYINT(1) DEFAULT 0, ADD COLUMN VerifiedByAdminName VARCHAR(255)`,
      (err) => {
        if (err && err.code !== "ER_DUP_FIELDNAME") {
          console.error("Alter Volunteers extended fields failed:", err.message);
        } else {
          // Mark pre-existing test/dummy volunteers as Verified so test data remains working
          db.query(
            `UPDATE Volunteers SET IsVerified = 1, VerifiedByAdminName = 'System/Initial' WHERE IsVerified IS NULL OR (IsVerified = 0 AND (UID IS NULL OR UID = ''))`,
            (err) => {
              if (err) console.error("Initial verification backfill failed:", err.message);
            }
          );
        }
      },
    );
    // ----------------------------------------
  }
});

// 4. Create a simple test route
app.get("/", (req, res) => {
  res.send("The Disaster Hub API is running!");
});

// --- OUR NEW API ROUTE ---
app.get("/api/requests", (req, res) => {
  // Join with Volunteers, Resources, Feedback, and Victims to show complete dispatch & victim vulnerability details
  const sql = `
        SELECT
            r.RequestID, r.RequestorName, r.UrgencyScore, r.Status, r.ShortMessage, r.DispatchedAt, r.CompletedAt, r.ResolvedAt, r.VictimID,
            c.CategoryName, l.AreaName, l.Latitude, l.Longitude,
            v.Name AS DispatcherName,
            rc.CategoryName AS DispatchedItemName,
            r.DispatchedQuantity,
            fb.IsSafe, fb.Rating, fb.FeedbackNote,
            vct.FullName AS VictimFullName, vct.PhoneNumber AS VictimPhone, vct.HomeAddress AS VictimAddress,
            vct.HouseholdCount, vct.HasVulnerableDependents, vct.MobilityStatus, vct.MedicalDependencies,
            vct.EmergencyContactName, vct.EmergencyContactPhone
        FROM HelpRequests r
        JOIN ResourceCategories c ON r.CategoryID = c.CategoryID
        JOIN Locations l ON r.LocationID = l.LocationID
        LEFT JOIN Volunteers v ON r.AssignedVolunteerID = v.VolunteerID
        LEFT JOIN Resources res ON r.AssignedResourceID = res.ResourceID
        LEFT JOIN ResourceCategories rc ON res.CategoryID = rc.CategoryID
        LEFT JOIN Feedback fb ON r.RequestID = fb.RequestID
        LEFT JOIN Victims vct ON r.VictimID = vct.VictimID
        ORDER BY FIELD(r.Status, 'Pending', 'Dispatched', 'Completed', 'Resolved') ASC, r.UrgencyScore DESC;
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
app.get("/api/resources", (req, res) => {
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

app.get("/api/resource-categories", (req, res) => {
  db.query(
    "SELECT CategoryID, CategoryName, UnitOfMeasure FROM ResourceCategories ORDER BY CategoryName",
    (err, results) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json(results);
    },
  );
});

app.get("/api/locations", (req, res) => {
  db.query(
    "SELECT LocationID, AreaName FROM Locations WHERE AreaName != 'Live SOS Location' ORDER BY AreaName",
    (err, results) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json(results);
    },
  );
});

app.post("/api/resources", (req, res) => {
  const { categoryId, locationId, quantity } = req.body;
  const qty = parseInt(quantity);

  if (!categoryId || !locationId || isNaN(qty)) {
    return res.status(400).json({ error: "Missing or invalid fields" });
  }

  // Check if a resource of this category already exists at this location
  const checkSql =
    "SELECT ResourceID FROM Resources WHERE CategoryID = ? AND CurrentLocationID = ? LIMIT 1";
  db.query(checkSql, [categoryId, locationId], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });

    if (results.length > 0) {
      // Update existing row
      const updateSql =
        "UPDATE Resources SET Quantity = Quantity + ?, Status = 'Available' WHERE ResourceID = ?";
      db.query(updateSql, [qty, results[0].ResourceID], (err) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json({
          message: "Resource quantity updated and status set to Available.",
        });
      });
    } else {
      // Insert new row
      const insertSql =
        "INSERT INTO Resources (CategoryID, CurrentLocationID, Quantity, Status) VALUES (?, ?, ?, 'Available')";
      db.query(insertSql, [categoryId, locationId, qty], (err) => {
        if (err) return res.status(500).json({ error: err.message });
        res.status(201).json({ message: "New resource added successfully." });
      });
    }
  });
});
// -------------------------

// --- SHELTERS API ROUTE ---
app.get("/api/shelters", (req, res) => {
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

// --- UPDATE FCM TOKEN (called when Firebase rotates the token on the device) ---
app.post("/api/update-fcm-token", (req, res) => {
  const { requestId, fcmToken } = req.body;
  if (!requestId || !fcmToken) {
    return res.status(400).json({ error: "Missing requestId or fcmToken" });
  }
  const sql = `UPDATE HelpRequests SET FCMToken = ? WHERE RequestID = ?`;
  db.query(sql, [fcmToken, requestId], (err, result) => {
    if (err)
      return res.status(500).json({ error: "Failed to update FCM token" });
    if (result.affectedRows === 0)
      return res.status(404).json({ error: "Request not found" });
    res.json({ message: "FCM token updated successfully" });
  });
});
// -------------------------

// --- RECEIVE SOS FROM FLUTTER APP ---
app.post("/api/sos", (req, res) => {
  const {
    RequestorName,
    CategoryID,
    UrgencyScore,
    Latitude,
    Longitude,
    ShortMessage,
    FCMToken,
    victimId,
    authUid
  } = req.body;

  const latVal = parseFloat(Latitude) || 0.0;
  const lonVal = parseFloat(Longitude) || 0.0;
  const catIdVal = parseInt(CategoryID) || 1;

  const saveHelpRequest = (vId, scoreMultiplier = 0) => {
    const rawUrgency = Math.min(10, Math.max(1, parseInt(UrgencyScore) || 5));
    const boostPoints = Math.min(3, Math.floor(scoreMultiplier / 10));
    const finalUrgencyScore = Math.min(10, Math.max(1, rawUrgency + boostPoints));

    const insertLocationSql = `
          INSERT INTO Locations (AreaName, Latitude, Longitude, ZoneType)
          VALUES ('Live SOS Location', ?, ?, 'Urban');
      `;

    db.query(insertLocationSql, [latVal, lonVal], (err, locResult) => {
      if (err) {
        console.error("SOS Location Insert Error:", err.message);
        return res.status(500).json({ error: `Failed to save location: ${err.message}` });
      }

      const newLocationId = locResult.insertId;

      // Ensure CategoryID exists in ResourceCategories to prevent Foreign Key constraint error
      db.query(`SELECT CategoryID FROM ResourceCategories WHERE CategoryID = ? LIMIT 1`, [catIdVal], (catErr, catResults) => {
        let validCatId = catIdVal;
        if (catErr || !catResults || catResults.length === 0) {
          // Auto-create category if missing
          db.query(`INSERT IGNORE INTO ResourceCategories (CategoryID, CategoryName, UnitOfMeasure) VALUES (?, 'Emergency Relief', 'units')`, [catIdVal], (iErr) => {
            if (iErr) console.error("Auto-category creation warning:", iErr.message);
            doInsert(newLocationId, catIdVal, vId, finalUrgencyScore);
          });
        } else {
          doInsert(newLocationId, validCatId, vId, finalUrgencyScore);
        }
      });
    });
  };

  const doInsert = (newLocationId, validCatId, vId, finalUrgencyScore) => {
    const insertRequestSql = `
            INSERT INTO HelpRequests (RequestorName, LocationID, CategoryID, UrgencyScore, Status, ShortMessage, FCMToken, VictimID)
            VALUES (?, ?, ?, ?, 'Pending', ?, ?, ?);
        `;

    db.query(
      insertRequestSql,
      [
        RequestorName || 'Registered Victim',
        newLocationId,
        validCatId,
        finalUrgencyScore,
        ShortMessage || '',
        FCMToken || null,
        vId || null
      ],
      (err, reqResult) => {
        if (err) {
          console.error("SOS HelpRequest Insert Error:", err.message);

          // Fallback if VictimID column is not yet present on remote DB
          if (err.code === "ER_BAD_FIELD_ERROR" || (err.message && err.message.includes("VictimID"))) {
            const fallbackSql = `
              INSERT INTO HelpRequests (RequestorName, LocationID, CategoryID, UrgencyScore, Status, ShortMessage, FCMToken)
              VALUES (?, ?, ?, ?, 'Pending', ?, ?);
            `;
            db.query(fallbackSql, [RequestorName || 'Registered Victim', newLocationId, validCatId, finalUrgencyScore, ShortMessage || '', FCMToken || null], (fErr, fResult) => {
              if (fErr) {
                console.error("SOS Fallback Insert Error:", fErr.message);
                return res.status(500).json({ error: `Failed to save SOS request: ${fErr.message}` });
              }

              io.emit("new_sos", {
                RequestID: fResult.insertId,
                RequestorName: RequestorName || 'Registered Victim',
                CategoryID: validCatId,
                UrgencyScore: finalUrgencyScore,
                ShortMessage: ShortMessage || '',
                Latitude: latVal,
                Longitude: lonVal,
                Status: "Pending",
                CreatedAt: new Date()
              });

              return res.status(201).json({
                message: "SOS Received successfully!",
                requestId: fResult.insertId,
              });
            });
            return;
          }

          return res.status(500).json({ error: `Failed to save SOS request: ${err.message}` });
        }

        io.emit("new_sos", {
          RequestID: reqResult.insertId,
          RequestorName: RequestorName || 'Registered Victim',
          CategoryID: validCatId,
          UrgencyScore: finalUrgencyScore,
          ShortMessage: ShortMessage || '',
          Latitude: latVal,
          Longitude: lonVal,
          Status: "Pending",
          CreatedAt: new Date(),
          VictimID: vId || null
        });

        res.status(201).json({
          message: "SOS Received successfully!",
          requestId: reqResult.insertId,
        });
      },
    );
  };

  if (victimId || authUid) {
    const findVictimSql = victimId 
      ? `SELECT VictimID, MobilityStatus, HasVulnerableDependents FROM Victims WHERE VictimID = ? LIMIT 1`
      : `SELECT VictimID, MobilityStatus, HasVulnerableDependents FROM Victims WHERE AuthUID = ? LIMIT 1`;
    const param = victimId || authUid;

    db.query(findVictimSql, [param], (err, results) => {
      let vId = null;
      let scoreBoost = 0;
      if (!err && results && results.length > 0) {
        vId = results[0].VictimID;
        const mobility = results[0].MobilityStatus;
        if (mobility === 'Bedbound') scoreBoost += 25;
        else if (mobility === 'Wheelchair') scoreBoost += 20;
        else if (mobility === 'Requires Assistance') scoreBoost += 15;

        if (results[0].HasVulnerableDependents == 1) scoreBoost += 10;
      }
      saveHelpRequest(vId, scoreBoost);
    });
  } else {
    saveHelpRequest(null, 0);
  }
});
// --- VOLUNTEER FLEET API ROUTE ---
app.get("/api/volunteers", (req, res) => {
  const sql = `
        SELECT VolunteerID, Name, Email, UID, Gender, Age, Location, Latitude, Longitude, Role, Status, PhoneNumber, HomeAddress, IsVerified, VerifiedByAdminName
        FROM Volunteers
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
app.get("/api/requests/:requestId", (req, res) => {
  const { requestId } = req.params;
  const sql = `
        SELECT r.*, v.Name AS VolunteerName, v.PhoneNumber AS VolunteerPhone, v.HomeAddress AS VolunteerAddress,
        v.Gender AS VolunteerGender, v.Age AS VolunteerAge, v.Role AS VolunteerRole,
        v.Latitude AS VolLat, v.Longitude AS VolLon,
        c.CategoryName AS DispatchedCategoryName, c.UnitOfMeasure,
        l.Latitude, l.Longitude,
        fb.IsSafe, fb.Rating, fb.FeedbackNote
        FROM HelpRequests r
        LEFT JOIN Volunteers v ON r.AssignedVolunteerID = v.VolunteerID
        LEFT JOIN Resources rsc ON r.AssignedResourceID = rsc.ResourceID
        LEFT JOIN ResourceCategories c ON rsc.CategoryID = c.CategoryID
        LEFT JOIN Locations l ON r.LocationID = l.LocationID
        LEFT JOIN Feedback fb ON r.RequestID = fb.RequestID
        WHERE r.RequestID = ?
    `;
  db.query(sql, [requestId], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    if (results.length === 0)
      return res.status(404).json({ error: "Not found" });
    res.json(results[0]);
  });
});

// --- NEW CHAT/MESSAGES ROUTE ---
app.get("/api/messages/:requestId", (req, res) => {
  const { requestId } = req.params;
  const sql = `SELECT * FROM Messages WHERE RequestID = ? ORDER BY SentAt ASC`;
  db.query(sql, [requestId], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    res.json(results);
  });
});

app.post("/api/messages", (req, res) => {
  const { requestId, senderRole, senderId, text } = req.body;
  const sql = `INSERT INTO Messages (RequestID, SenderRole, SenderID, MessageText) VALUES (?, ?, ?, ?)`;
  db.query(sql, [requestId, senderRole, senderId, text], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });

    // Also emit via socket.io for the web app
    io.to(`request_${requestId}`).emit("new_message", {
      MessageID: result.insertId,
      RequestID: requestId,
      SenderRole: senderRole,
      SenderID: senderId,
      MessageText: text,
      SentAt: new Date(),
    });

    res.status(201).json({ success: true });
  });
});

// --- ADMIN VERIFY ROUTE ---
app.get("/api/admin/verify", (req, res) => {
  const { email } = req.query;
  if (!email) return res.status(400).json({ error: "Missing email parameter" });

  // We check if this email exists in the Admins table
  const sql = `SELECT AdminID, Admin_name FROM Admins WHERE Email = ? LIMIT 1`;
  db.query(sql, [email], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    if (results.length > 0) {
      res.json({ isAdmin: true, adminName: results[0].Admin_name });
    } else {
      res.json({ isAdmin: false });
    }
  });
});

// --- VOLUNTEER LOCATION UPDATE ---
app.post("/api/volunteer/location", (req, res) => {
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

// --- STORE VOLUNTEER FCM TOKEN ---
app.post("/api/volunteer/fcm-token", (req, res) => {
  const { uid, fcmToken } = req.body;
  if (!uid || !fcmToken) {
    return res.status(400).json({ error: "Missing uid or fcmToken" });
  }
  const sql = `UPDATE Volunteers SET FCMToken = ? WHERE UID = ?`;
  db.query(sql, [fcmToken, uid], (err, result) => {
    if (err) return res.status(500).json({ error: err.message });
    if (result.affectedRows === 0)
      return res.status(404).json({ error: "Volunteer not found" });
    res.json({ message: "FCM token saved" });
  });
});

app.post("/api/volunteers", (req, res) => {
  const { uid, email, name, status, location, age, gender, role, phoneNumber, homeAddress } = req.body;

  if (!uid || !email || !name) {
    return res.status(400).json({ error: "Missing required fields" });
  }

  const sql = `
        INSERT INTO Volunteers (Name, Email, UID, Gender, Age, Location, Role, Status, PhoneNumber, HomeAddress, IsVerified)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
    `;

  db.query(
    sql,
    [
      name,
      email,
      uid,
      gender || null,
      age || null,
      location || null,
      role || "General",
      status || "Pending",
      phoneNumber || null,
      homeAddress || null,
    ],
    (err, result) => {
      if (err) {
        console.error("Error inserting volunteer:", err);
        return res
          .status(500)
          .json({ error: "Failed to create volunteer profile" });
      }
      res.status(201).json({
        message: "Volunteer created successfully. Pending Admin verification.",
        id: result.insertId,
      });
    },
  );
});

// --- ADMIN VERIFY VOLUNTEER API ROUTE ---
app.post("/api/volunteers/:id/verify", (req, res) => {
  const { id } = req.params;
  const { isVerified, adminName } = req.body;

  const verifiedVal = isVerified ? 1 : 0;
  const statusVal = isVerified ? "Available" : "Rejected";
  const verifierName = adminName || "Admin";

  const sql = `
        UPDATE Volunteers
        SET IsVerified = ?, VerifiedByAdminName = ?, Status = ?
        WHERE VolunteerID = ?;
    `;

  db.query(sql, [verifiedVal, verifierName, statusVal, id], (err, result) => {
    if (err) {
      console.error("Error verifying volunteer:", err);
      return res.status(500).json({ error: "Failed to verify volunteer" });
    }
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: "Volunteer not found" });
    }
    res.json({
      success: true,
      message: `Volunteer #${id} status updated to ${statusVal} by ${verifierName}`,
    });
  });
});

// --- GLOBAL STATS API ROUTE ---
app.get("/api/stats", (req, res) => {
  const sosSql = `SELECT Status, COUNT(*) AS count FROM HelpRequests GROUP BY Status`;
  const volSql = `SELECT COUNT(*) AS count FROM Volunteers WHERE Status = 'Available' AND IsVerified = 1 AND UID IS NOT NULL AND Email IS NOT NULL`;
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
          completed: 0,
          volunteers: volResult[0].count,
          lowStockCount: stockResult[0].count,
        };

        sosResults.forEach((r) => {
          if (r.Status === "Pending") stats.pending = r.count;
          if (r.Status === "Dispatched") stats.dispatched = r.count;
          if (r.Status === "Completed") stats.completed = r.count;
        });

        res.json(stats);
      });
    });
  });
});

// --- COMPLETE SOS MISSION API ROUTE ---
app.post("/api/requests/:requestId/complete", (req, res) => {
  const { requestId } = req.params;
  const { uid, volunteerId } = req.body;

  if (!requestId) {
    return res.status(400).json({ error: "Missing requestId parameter" });
  }

  // 1. Find the HelpRequest and Assigned Volunteer
  const findSql = `SELECT RequestID, Status, AssignedVolunteerID, FCMToken FROM HelpRequests WHERE RequestID = ?`;
  db.query(findSql, [requestId], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    if (results.length === 0) return res.status(404).json({ error: "Request not found" });

    const reqData = results[0];
    const assignedVolId = reqData.AssignedVolunteerID;

    // 2. Update HelpRequest status to Completed
    const updateReqSql = `UPDATE HelpRequests SET Status = 'Completed', CompletedAt = NOW() WHERE RequestID = ?`;
    db.query(updateReqSql, [requestId], (err) => {
      if (err) {
        console.error("Error updating HelpRequest status to Completed:", err.message);
        return res.status(500).json({ error: `Failed to update request status: ${err.message}` });
      }

      // 3. Reset Volunteer status back to Available so they can be dispatched again
      if (assignedVolId || volunteerId || uid) {
        let updateVolSql = `UPDATE Volunteers SET Status = 'Available' WHERE VolunteerID = ?`;
        let volParam = assignedVolId || volunteerId;

        if (uid && !volParam) {
          updateVolSql = `UPDATE Volunteers SET Status = 'Available' WHERE UID = ?`;
          volParam = uid;
        }

        if (volParam) {
          db.query(updateVolSql, [volParam], (err) => {
            if (err) console.error("Failed to reset volunteer status:", err.message);
          });
        }
      }

      // 4. Emit Socket.IO Event
      io.emit("mission_completed", {
        RequestID: parseInt(requestId),
        VolunteerID: assignedVolId || volunteerId,
        CompletedAt: new Date(),
        Status: "Completed"
      });

      // 5. Send FCM Push Notification to Victim
      if (reqData.FCMToken && admin.apps.length > 0) {
        admin.messaging().send({
          token: reqData.FCMToken,
          notification: {
            title: "✅ Rescue Mission Completed",
            body: `Your emergency request #${requestId} has been marked completed by the rescue team. Stay safe!`,
          },
          data: {
            requestId: String(requestId),
            type: "completed",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "high_importance_channel",
              priority: "high",
              defaultVibrateTimings: true,
              defaultSound: true,
            },
          },
        }).catch(e => console.error("FCM Send Error:", e.message));
      }

      res.json({
        success: true,
        message: `Mission #${requestId} marked as Completed. Volunteer is now Available.`
      });
    });
  });
});

// --- ADMIN MARK SOS DISPATCH RESOLVED API ROUTE ---
app.post("/api/requests/:requestId/resolve", (req, res) => {
  const { requestId } = req.params;
  const { adminName } = req.body;

  if (!requestId) {
    return res.status(400).json({ error: "Missing requestId parameter" });
  }

  // 1. Find request details
  const findSql = `SELECT RequestID, Status, AssignedVolunteerID, FCMToken FROM HelpRequests WHERE RequestID = ?`;
  db.query(findSql, [requestId], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    if (results.length === 0) return res.status(404).json({ error: "Request not found" });

    const reqData = results[0];
    const assignedVolId = reqData.AssignedVolunteerID;

    // 2. Update HelpRequest status to Resolved
    const updateReqSql = `UPDATE HelpRequests SET Status = 'Resolved', ResolvedAt = NOW() WHERE RequestID = ?`;
    db.query(updateReqSql, [requestId], (err) => {
      if (err) return res.status(500).json({ error: `Failed to resolve request: ${err.message}` });

      // 3. Ensure Volunteer status is set to Available if assigned
      if (assignedVolId) {
        db.query(`UPDATE Volunteers SET Status = 'Available' WHERE VolunteerID = ?`, [assignedVolId], (err) => {
          if (err) console.error("Failed to reset volunteer status on resolve:", err.message);
        });
      }

      // 4. Emit Socket.IO event
      io.emit("dispatch_resolved", {
        RequestID: parseInt(requestId),
        Status: "Resolved",
        ResolvedAt: new Date(),
        AdminName: adminName || "Admin"
      });

      // 5. Send FCM Push Notification to Victim
      if (reqData.FCMToken && admin.apps.length > 0) {
        admin.messaging().send({
          token: reqData.FCMToken,
          notification: {
            title: "🚨 Rescue Dispatch Resolved",
            body: "Central Command has resolved your request. Please confirm your safety and rate your response team.",
          },
          data: {
            requestId: String(requestId),
            type: "resolved",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "high_importance_channel",
              priority: "high",
              defaultVibrateTimings: true,
              defaultSound: true,
            },
          },
        }).catch(e => console.error("FCM Send Error:", e.message));
      }

      res.json({
        success: true,
        message: `Dispatch #${requestId} marked as Resolved.`
      });
    });
  });
});

// --- SUBMIT VICTIM FEEDBACK & RATING API ROUTE ---
app.post("/api/requests/:requestId/feedback", (req, res) => {
  const { requestId } = req.params;
  const { isSafe, rating, note } = req.body;

  if (!requestId) {
    return res.status(400).json({ error: "Missing requestId parameter" });
  }

  const isSafeVal = (isSafe === true || isSafe === 1 || isSafe === 'true') ? 1 : 0;
  const ratingVal = parseInt(rating) || 5;
  const noteVal = note || "";

  // Check if feedback already exists for this request
  db.query(`SELECT FeedbackID FROM Feedback WHERE RequestID = ?`, [requestId], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    if (results && results.length > 0) {
      return res.status(400).json({ error: "Feedback has already been submitted for this request" });
    }

    const sql = `
      INSERT INTO Feedback (RequestID, IsSafe, Rating, FeedbackNote)
      VALUES (?, ?, ?, ?);
    `;

    db.query(sql, [requestId, isSafeVal, ratingVal, noteVal], (err, result) => {
      if (err) {
        console.error("Error saving feedback:", err.message);
        return res.status(500).json({ error: "Failed to submit feedback" });
      }

      // Emit Socket.IO Event for Admin Dashboard Sync
      io.emit("feedback_received", {
        RequestID: parseInt(requestId),
        IsSafe: isSafeVal,
        Rating: ratingVal,
        FeedbackNote: noteVal,
        SubmittedAt: new Date()
      });

      res.json({
        success: true,
        message: "Feedback submitted successfully! Thank you for helping central command."
      });
    });
  });
});

// --- GET FEEDBACK FOR REQUEST ---
app.get("/api/requests/:requestId/feedback", (req, res) => {
  const { requestId } = req.params;
  const sql = `SELECT * FROM Feedback WHERE RequestID = ? LIMIT 1`;
  db.query(sql, [requestId], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    if (results.length === 0) return res.status(404).json({ error: "No feedback found" });
    res.json(results[0]);
  });
});

// --- VICTIM PROFILE APIS ---
app.post("/api/victims", (req, res) => {
  const {
    authUid,
    fullName,
    phoneNumber,
    homeAddress,
    age,
    gender,
    householdCount,
    hasVulnerableDependents,
    mobilityStatus,
    medicalDependencies,
    primaryLanguage,
    petCount,
    emergencyContactName,
    emergencyContactPhone
  } = req.body;

  if (!authUid || !fullName) {
    return res.status(400).json({ error: "Missing authUid or fullName parameter" });
  }

  const ageVal = age ? parseInt(age) : null;
  const householdCountVal = householdCount ? parseInt(householdCount) : 1;
  const vulnerableVal = (hasVulnerableDependents === true || hasVulnerableDependents === 1 || hasVulnerableDependents === 'true') ? 1 : 0;
  const mobilityVal = mobilityStatus || 'Fully Mobile';
  const petCountVal = petCount ? parseInt(petCount) : 0;

  const sql = `
    INSERT INTO Victims (
      AuthUID, FullName, PhoneNumber, HomeAddress, Age, Gender,
      HouseholdCount, HasVulnerableDependents, MobilityStatus, MedicalDependencies,
      PrimaryLanguage, PetCount, EmergencyContactName, EmergencyContactPhone
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE
      FullName = VALUES(FullName),
      PhoneNumber = VALUES(PhoneNumber),
      HomeAddress = VALUES(HomeAddress),
      Age = VALUES(Age),
      Gender = VALUES(Gender),
      HouseholdCount = VALUES(HouseholdCount),
      HasVulnerableDependents = VALUES(HasVulnerableDependents),
      MobilityStatus = VALUES(MobilityStatus),
      MedicalDependencies = VALUES(MedicalDependencies),
      PrimaryLanguage = VALUES(PrimaryLanguage),
      PetCount = VALUES(PetCount),
      EmergencyContactName = VALUES(EmergencyContactName),
      EmergencyContactPhone = VALUES(EmergencyContactPhone);
  `;

  db.query(
    sql,
    [
      authUid, fullName, phoneNumber || null, homeAddress || null, ageVal, gender || null,
      householdCountVal, vulnerableVal, mobilityVal, medicalDependencies || null,
      primaryLanguage || 'Local', petCountVal, emergencyContactName || null, emergencyContactPhone || null
    ],
    (err, result) => {
      if (err) {
        console.error("Error creating/updating victim profile:", err.message);
        return res.status(500).json({ error: err.message });
      }

      db.query(`SELECT * FROM Victims WHERE AuthUID = ? LIMIT 1`, [authUid], (err, results) => {
        if (err || results.length === 0) {
          return res.json({ success: true, victimId: result.insertId || null });
        }
        res.json({ success: true, victim: results[0] });
      });
    }
  );
});

app.get("/api/victims/me", (req, res) => {
  const { uid } = req.query;
  if (!uid) return res.status(400).json({ error: "Missing uid parameter" });

  const sql = `SELECT * FROM Victims WHERE AuthUID = ? LIMIT 1`;
  db.query(sql, [uid], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    if (results.length === 0) return res.status(404).json({ error: "Victim profile not found" });
    res.json(results[0]);
  });
});

// --- GET CURRENT VOLUNTEER PROFILE BY FIREBASE UID ---
app.get("/api/me", (req, res) => {
  const { uid } = req.query;
  if (!uid) return res.status(400).json({ error: "Missing uid parameter" });

  const sql = `
        SELECT VolunteerID, Name, Email, Role, Status, Location, PhoneNumber, HomeAddress, Gender, Age, IsVerified, VerifiedByAdminName
        FROM Volunteers
        WHERE UID = ?
        LIMIT 1;
    `;
  db.query(sql, [uid], (err, results) => {
    if (err) return res.status(500).json({ error: err.message });
    if (results.length === 0)
      return res
        .status(404)
        .json({ error: "Volunteer profile not found for this account." });
    res.json(results[0]);
  });
});
// -------------------------------------------------------

// --- PROXIMITY & SKILL APIS FOR DISPATCH ---

// Mapping SOS Categories to Recommended Volunteer Roles
const ROLE_MAPPING = {
  1: ["Medical Aid", "First Responder"], // Medical Kits
  2: ["Logistics", "Supply Coordinator"], // Drinking Water
  3: ["Logistics", "Supply Coordinator"], // Dry Food Rations
  4: ["Rescue Driver", "First Responder"], // Rescue Boats
};

// Get nearest available resources for a specific category
app.get("/api/nearest-resources", (req, res) => {
  const { lat, lon, categoryId } = req.query;
  if (!lat || !lon || !categoryId)
    return res.status(400).json({ error: "Missing parameters" });

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
app.get("/api/nearest-volunteers", (req, res) => {
  const { categoryId } = req.query;

  const sql = `
        SELECT VolunteerID, Name, Role, Location, Status
        FROM Volunteers
        WHERE Status = 'Available' AND IsVerified = 1
        ORDER BY VolunteerID ASC;
    `;

  db.query(sql, (err, results) => {
    if (err) return res.status(500).json({ error: err.message });

    // Add recommendation flag based on category mapping
    const recommendedRoles = ROLE_MAPPING[categoryId] || [];
    const enrichedResults = results.map((v) => ({
      ...v,
      isRecommended: recommendedRoles.includes(v.Role),
    }));

    // Sort by recommendation first
    enrichedResults.sort((a, b) =>
      b.isRecommended === a.isRecommended ? 0 : b.isRecommended ? 1 : -1,
    );

    res.json(enrichedResults);
  });
});

// Get ALL available resources (any category), sorted by proximity
app.get("/api/available-resources", (req, res) => {
  const { lat, lon } = req.query;
  if (!lat || !lon)
    return res.status(400).json({ error: "Missing lat/lon parameters" });

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
app.get("/api/nearest-volunteers", (req, res) => {
  const { lat, lon } = req.query;
  let sql = `
        SELECT VolunteerID, Name, Role, Location, Latitude, Longitude, Status
        FROM Volunteers
        WHERE Status = 'Available' AND IsVerified = 1
    `;

  if (lat && lon) {
    sql = `
            SELECT VolunteerID, Name, Role, Location, Latitude, Longitude, Status,
            (6371 * acos(
                cos(radians(?)) * cos(radians(Latitude)) * cos(radians(Longitude) - radians(?))
                + sin(radians(?)) * sin(radians(Latitude))
            )) AS distance
            FROM Volunteers
            WHERE Status = 'Available' AND IsVerified = 1 AND Latitude IS NOT NULL AND Longitude IS NOT NULL
            ORDER BY distance ASC
            LIMIT 10;
        `;
    db.query(sql, [lat, lon, lat], (err, results) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json(results);
    });
  } else {
    db.query(sql + " LIMIT 10", (err, results) => {
      if (err) return res.status(500).json({ error: err.message });
      res.json(results);
    });
  }
});

app.post("/api/dispatch", (req, res) => {
  const { volunteerId, resourceId, requestId, quantity } = req.body;
  const dispatchQty = parseInt(quantity) || 1;

  if (!volunteerId || !resourceId || !requestId) {
    return res.status(400).json({ error: "Missing required fields" });
  }

  // Use a simplified multi-step update for now
  const updateV =
    "UPDATE Volunteers SET Status = 'Active' WHERE VolunteerID = ?";
  const updateR =
    "UPDATE Resources SET Quantity = Quantity - ? WHERE ResourceID = ? AND Quantity >= ?";
  const updateReq =
    "UPDATE HelpRequests SET Status = 'Dispatched', AssignedVolunteerID = ?, AssignedResourceID = ?, DispatchedQuantity = ?, DispatchedAt = NOW() WHERE RequestID = ?";

  db.query(updateV, [volunteerId], (err) => {
    if (err) return res.status(500).json({ error: "Volunteer update failed" });

    db.query(updateR, [dispatchQty, resourceId, dispatchQty], (err, result) => {
      if (err) return res.status(500).json({ error: "Resource update failed" });
      if (result.affectedRows === 0)
        return res
          .status(400)
          .json({ error: "Insufficient resource quantity" });

      db.query(
        updateReq,
        [volunteerId, resourceId, dispatchQty, requestId],
        (err) => {
          if (err)
            return res.status(500).json({ error: "Request update failed" });

          // Notify via Socket.IO
          io.emit("dispatch_assigned", {
            RequestID: requestId,
            VolunteerID: volunteerId,
            ResourceID: resourceId,
            DispatchedQuantity: dispatchQty,
            DispatchedAt: new Date(),
          });

          // Fetch FCM Token and send Push Notification if available
          db.query(
            "SELECT FCMToken FROM HelpRequests WHERE RequestID = ?",
            [requestId],
            (err, reqRes) => {
              if (!err && reqRes.length > 0 && reqRes[0].FCMToken) {
                if (admin.apps.length > 0) {
                  // Check if Firebase Admin is initialized
                  admin
                    .messaging()
                    .send({
                      token: reqRes[0].FCMToken,
                      notification: {
                        title: "🚨 Rescue Dispatched!",
                        body: `Help is on the way! Your SOS request #${requestId} has been dispatched.`,
                      },
                      // data is required for background/terminated app to wake up
                      data: {
                        requestId: String(requestId),
                        type: "dispatch",
                      },
                      android: {
                        priority: "high",
                        notification: {
                          channelId: "high_importance_channel",
                          priority: "high",
                          defaultVibrateTimings: true,
                          defaultSound: true,
                        },
                      },
                    })
                    .then(() => {
                      console.log(
                        `✅ Push notification sent for request #${requestId}`,
                      );
                    })
                    .catch((e) => {
                      console.error("FCM Send Error:", e.message || e);
                      // If the token is no longer valid, clear it so we don't keep trying
                      if (
                        e.code ===
                          "messaging/registration-token-not-registered" ||
                        e.code === "messaging/invalid-registration-token"
                      ) {
                        db.query(
                          "UPDATE HelpRequests SET FCMToken = NULL WHERE RequestID = ?",
                          [requestId],
                          () => {
                            console.log(
                              `🗑️ Cleared invalid FCM token for request #${requestId}`,
                            );
                          },
                        );
                      }
                    });
                }
              }
            },
          );

          // Notify the assigned volunteer
          db.query(
            "SELECT FCMToken FROM Volunteers WHERE VolunteerID = ?",
            [volunteerId],
            (err, volRes) => {
              if (!err && volRes.length > 0 && volRes[0].FCMToken) {
                if (admin.apps.length > 0) {
                  admin
                    .messaging()
                    .send({
                      token: volRes[0].FCMToken,
                      notification: {
                        title: "🚨 Mission Assigned!",
                        body: `You have been assigned to rescue mission #${requestId}. Open the app to begin.`,
                      },
                      data: {
                        requestId: String(requestId),
                        type: "mission_assigned",
                      },
                      android: {
                        priority: "high",
                        notification: {
                          channelId: "rescue_missions_channel",
                          priority: "high",
                          defaultVibrateTimings: true,
                          defaultSound: true,
                        },
                      },
                    })
                    .then(() =>
                      console.log(
                        `✅ Volunteer #${volunteerId} notified for mission #${requestId}`,
                      ),
                    )
                    .catch((e) => {
                      console.error("Volunteer FCM Error:", e.message || e);
                      if (
                        e.code ===
                          "messaging/registration-token-not-registered" ||
                        e.code === "messaging/invalid-registration-token"
                      ) {
                        db.query(
                          "UPDATE Volunteers SET FCMToken = NULL WHERE VolunteerID = ?",
                          [volunteerId],
                          () =>
                            console.log(
                              `🗑️ Cleared invalid FCM token for volunteer #${volunteerId}`,
                            ),
                        );
                      }
                    });
                }
              }
            },
          );

          res.json({
            message: `Dispatch successful! ${dispatchQty} units have been deployed.`,
          });
        },
      );
    });
  });
});

// 5. Start the server
const PORT = 3000;
server.listen(PORT, () => {
  console.log(
    `🚀 Real-time Command Server is running on http://localhost:${PORT}`,
  );
});
