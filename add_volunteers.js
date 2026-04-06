require('dotenv').config();
const mysql = require('mysql2');

const db = mysql.createConnection(process.env.DATABASE_URL);

db.connect((err) => {
    if (err) throw err;
    console.log("Connected to database.");

    // CREATE TABLE
    const createTableQuery = `
        CREATE TABLE IF NOT EXISTS Volunteers (
            VolunteerID INT AUTO_INCREMENT PRIMARY KEY,
            Name VARCHAR(255) NOT NULL,
            Gender VARCHAR(50),
            Age INT,
            Location VARCHAR(255),
            Role VARCHAR(100),
            Status VARCHAR(50) DEFAULT 'Pending'
        );
    `;

    db.query(createTableQuery, (err) => {
        if (err) throw err;
        console.log("Volunteers table is ready!");

        const dummyData = [
            ['Abir Hasan', 'Male', 24, 'Dhaka', 'Field Responder', 'Active'],
            ['Sadia Rahman', 'Female', 27, 'Sylhet', 'Medical Aid', 'Active'],
            ['Tahsan Khan', 'Male', 31, 'Chittagong', 'Logistics', 'Active'],
            ['Nusrat Faria', 'Female', 22, 'Barisal', 'Communication', 'Pending'],
            ['Kamal Uddin', 'Male', 45, 'Khulna', 'Rescue Driver', 'Active'],
            ['Sumi Akter', 'Female', 29, 'Rajshahi', 'First Responder', 'Offline'],
            ['Rafiqul Islam', 'Male', 35, 'Dhaka', 'Supply Coordinator', 'Active'],
            ['Fahima Begum', 'Female', 30, 'Sylhet', 'Medical Aid', 'Active']
        ];

        const insertQuery = `
            INSERT INTO Volunteers (Name, Gender, Age, Location, Role, Status) 
            VALUES ?
        `;

        // Check if data already exists to avoid duplication entirely
        db.query("SELECT COUNT(*) as count FROM Volunteers", (err, result) => {
            if (err) throw err;
            if (result[0].count === 0) {
                db.query(insertQuery, [dummyData], (err, results) => {
                    if (err) throw err;
                    console.log(`Inserted ${results.affectedRows} volunteers!`);
                    process.exit();
                });
            } else {
                console.log("Volunteers already exist. Skipping seed.");
                process.exit();
            }
        });
    });
});
