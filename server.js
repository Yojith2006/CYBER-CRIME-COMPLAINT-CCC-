const express = require('express');
const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Load environment variables from .env file if it exists
const ENV_PATH = path.join(__dirname, '.env');
if (fs.existsSync(ENV_PATH)) {
    const envConfig = fs.readFileSync(ENV_PATH, 'utf8');
    envConfig.split(/\r?\n/).forEach(line => {
        const trimmed = line.trim();
        if (trimmed.startsWith('#') || trimmed === '') return;
        const index = trimmed.indexOf('=');
        if (index > 0) {
            const key = trimmed.substring(0, index).trim();
            const val = trimmed.substring(index + 1).trim().replace(/^['"]|['"]$/g, '');
            process.env[key] = val;
        }
    });
}

// MySQL Connection Settings
const DB_CONFIG = {
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME || 'cybercrime',
    multipleStatements: true
};

const SCHEMA_PATH = path.join(__dirname, 'schema.sql');
const SEED_PATH = path.join(__dirname, 'seed_data.sql');

let pool;

// =====================================================================
// SQL PARSER (Cleans delimiter commands and splits statements)
// =====================================================================
function parseSqlStatements(sqlText) {
    const statements = [];
    let currentDelimiter = ';';
    let currentStatement = '';
    
    // Split by lines (handling both CRLF and LF)
    const lines = sqlText.split(/\r?\n/);
    
    for (let line of lines) {
        const trimmedLine = line.trim();
        
        // Skip empty lines or comment lines
        if (trimmedLine === '' || trimmedLine.startsWith('--') || trimmedLine.startsWith('#')) {
            continue;
        }
        
        // Check for DELIMITER statement (case insensitive)
        const delimiterMatch = trimmedLine.match(/^DELIMITER\s+(.+)$/i);
        if (delimiterMatch) {
            currentDelimiter = delimiterMatch[1].trim();
            continue;
        }
        
        // Accumulate line
        currentStatement += line + '\n';
        
        // Check if the current line ends with the active delimiter
        if (trimmedLine.endsWith(currentDelimiter)) {
            // Cut the delimiter from the end of the statement
            let stmt = currentStatement.trim();
            if (stmt.endsWith(currentDelimiter)) {
                stmt = stmt.slice(0, -currentDelimiter.length).trim();
            }
            if (stmt.length > 0) {
                statements.push(stmt);
            }
            currentStatement = '';
        }
    }
    
    // Catch any remaining statement
    if (currentStatement.trim() !== '') {
        let stmt = currentStatement.trim();
        if (stmt.endsWith(currentDelimiter)) {
            stmt = stmt.slice(0, -currentDelimiter.length).trim();
        }
        if (stmt.length > 0) {
            statements.push(stmt);
        }
    }
    
    return statements;
}

// =====================================================================
// DATABASE INITIALIZATION (MySQL Connect & Auto-Create)
// =====================================================================
async function initializeDatabase() {
    try {
        console.log('Connecting to MySQL server...');
        
        // 1. First connect without database name to ensure DB exists
        const tempConn = await mysql.createConnection({
            host: DB_CONFIG.host,
            user: DB_CONFIG.user,
            password: DB_CONFIG.password
        });
        
        console.log(`Ensuring database "${DB_CONFIG.database}" exists...`);
        await tempConn.query(`CREATE DATABASE IF NOT EXISTS ${DB_CONFIG.database}`);
        await tempConn.end();
        
        // 2. Initialize connection pool
        pool = mysql.createPool(DB_CONFIG);
        console.log(`Connected to MySQL database: ${DB_CONFIG.database}`);
        
        // 3. Check if tables are created (check if Users exists)
        const [tables] = await pool.query(
            `SELECT COUNT(*) as count FROM information_schema.tables 
             WHERE table_schema = ? AND table_name = 'Complaints'`,
            [DB_CONFIG.database]
        );
        
        if (tables[0].count === 0) {
            console.log('Database empty. Auto-initializing with schema & seeds...');
            
             // Read and run schema.sql
             if (fs.existsSync(SCHEMA_PATH)) {
                 console.log('Applying schema.sql...');
                 const schemaSql = fs.readFileSync(SCHEMA_PATH, 'utf8');
                 const schemaStatements = parseSqlStatements(schemaSql);
                 for (const stmt of schemaStatements) {
                     console.log(`Running DDL: ${stmt.substring(0, 80).replace(/\r?\n/g, ' ')}...`);
                     await pool.query(stmt);
                 }
                 console.log('✓ Applied schema.sql successfully');
             }
             
             // Read and run seed_data.sql
             if (fs.existsSync(SEED_PATH)) {
                 console.log('Applying seed_data.sql...');
                 const seedSql = fs.readFileSync(SEED_PATH, 'utf8');
                 const seedStatements = parseSqlStatements(seedSql);
                 for (const stmt of seedStatements) {
                     console.log(`Running DML: ${stmt.substring(0, 80).replace(/\r?\n/g, ' ')}...`);
                     await pool.query(stmt);
                 }
                 console.log('✓ Applied seed_data.sql successfully');
             }
        } else {
            console.log('MySQL Database contains existing tables. Ready.');
        }
    } catch (err) {
        console.error('MySQL database connection failed!');
        console.error('ERROR MESSAGE:', err.message);
        console.log('\n======================================================');
        console.log('IMPORTANT NOTE FOR SYSTEM SETUP:');
        console.log('Please make sure your MySQL database server is running.');
        console.log('If using XAMPP/WAMP, make sure Apache & MySQL modules are started.');
        console.log('======================================================\n');
        process.exit(1);
    }
}

// =====================================================================
// API ENDPOINTS (With SQL Query telemetry returned to frontend)
// =====================================================================

// --- AUTH & USER APIS ---

// Citizen Login
app.post('/api/auth/citizen/login', async (req, res) => {
    const { email } = req.body;
    const sql = 'SELECT * FROM Users WHERE Email = ?;';
    try {
        const [rows] = await pool.execute(sql, [email]);
        const user = rows[0];
        if (!user) {
            return res.status(401).json({ error: 'Invalid email address.', sql });
        }
        res.json({ message: 'Login successful', role: 'Citizen', user, sql });
    } catch (err) {
        res.status(500).json({ error: err.message, sql });
    }
});

// Citizen Registration
app.post('/api/auth/citizen/register', async (req, res) => {
    const { fullName, email, phone, aadhaar, address } = req.body;
    const sql = 'INSERT INTO Users (FullName, Email, PasswordHash, Phone, AadhaarNumber, Address) VALUES (?, ?, ?, ?, ?, ?);';
    try {
        const [result] = await pool.execute(sql, [fullName, email, 'hashed_password_dummy', phone, aadhaar, address]);
        const userId = result.insertId;
        
        // Fetch new user
        const fetchSql = 'SELECT * FROM Users WHERE UserID = ?;';
        const [rows] = await pool.execute(fetchSql, [userId]);
        
        res.status(201).json({ 
            message: 'Registration successful', 
            role: 'Citizen', 
            user: rows[0], 
            sql: `${sql}\n-- Then fetched via:\n${fetchSql}` 
        });
    } catch (err) {
        res.status(400).json({ error: err.message, sql });
    }
});

// Officer Login
app.post('/api/auth/officer/login', async (req, res) => {
    const { email, badgeNumber } = req.body;
    const sql = 'SELECT * FROM Officers WHERE Email = ? AND BadgeNumber = ?;';
    try {
        const [rows] = await pool.execute(sql, [email, badgeNumber]);
        const officer = rows[0];
        if (!officer) {
            return res.status(401).json({ error: 'Invalid email or badge number.', sql });
        }
        res.json({ message: 'Login successful', role: 'Officer', user: officer, sql });
    } catch (err) {
        res.status(500).json({ error: err.message, sql });
    }
});

// Admin Login
app.post('/api/auth/admin/login', async (req, res) => {
    const { email } = req.body;
    const sql = 'SELECT * FROM Admins WHERE Email = ?;';
    try {
        const [rows] = await pool.execute(sql, [email]);
        const admin = rows[0];
        if (!admin) {
            return res.status(401).json({ error: 'Invalid admin credentials.', sql });
        }
        res.json({ message: 'Login successful', role: 'Admin', user: admin, sql });
    } catch (err) {
        res.status(500).json({ error: err.message, sql });
    }
});


// --- CRIME & COMPLAINT APIS ---

// Get all crime types
app.get('/api/crime-types', async (req, res) => {
    const sql = 'SELECT * FROM CrimeTypes ORDER BY TypeName ASC;';
    try {
        const [rows] = await pool.query(sql);
        res.json({ data: rows, sql });
    } catch (err) {
        res.status(500).json({ error: err.message, sql });
    }
});

// Get complaint details list (using v_complaint_details View)
app.get('/api/complaints', async (req, res) => {
    const { userId, officerId } = req.query;
    try {
        let sql = 'SELECT * FROM v_complaint_details';
        let params = [];
        
        if (userId) {
            const [users] = await pool.execute('SELECT Email FROM Users WHERE UserID = ?;', [userId]);
            if (users.length > 0) {
                sql += ' WHERE CitizenEmail = ?';
                params.push(users[0].Email);
            }
        } else if (officerId) {
            const [officers] = await pool.execute('SELECT BadgeNumber FROM Officers WHERE OfficerID = ?;', [officerId]);
            if (officers.length > 0) {
                sql += ' WHERE OfficerBadge = ?';
                params.push(officers[0].BadgeNumber);
            }
        }
        
        sql += ' ORDER BY ComplaintID DESC;';
        const [rows] = await pool.execute(sql, params);
        res.json({ data: rows, sql });
    } catch (err) {
        res.status(500).json({ error: err.message, sql: 'SELECT * FROM v_complaint_details;' });
    }
});

// File a complaint (Citizen)
app.post('/api/complaints', async (req, res) => {
    const { userId, crimeTypeId, title, description, dateOfOccurrence, location, evidenceName, evidenceDescription } = req.body;
    
    const insertComplaintSql = 'INSERT INTO Complaints (UserID, CrimeTypeID, Title, Description, DateOfOccurrence, Location) VALUES (?, ?, ?, ?, ?, ?);';
    const insertEvidenceSql = 'INSERT INTO Evidence (ComplaintID, FileName, FilePath, FileType, FileSizeKB, Description) VALUES (?, ?, ?, ?, ?, ?);';
    
    let conn;
    try {
        conn = await pool.getConnection();
        await conn.beginTransaction();

        // 1. Insert complaint (triggers trg_after_complaint_insert to create StatusHistory log)
        const [compResult] = await conn.execute(insertComplaintSql, [userId, crimeTypeId, title, description, dateOfOccurrence, location]);
        const complaintId = compResult.insertId;

        // 2. Insert evidence if available
        let evLogged = '';
        if (evidenceName) {
            await conn.execute(insertEvidenceSql, [
                complaintId, 
                evidenceName, 
                `/uploads/evidence/case_${complaintId}/${evidenceName.toLowerCase().replace(/[^a-z0-9.]/g, '_')}`, 
                evidenceName.endsWith('.pdf') ? 'application/pdf' : 'image/png', 
                Math.floor(Math.random() * 500) + 50,
                evidenceDescription || 'Uploaded proof'
            ]);
            evLogged = `\n${insertEvidenceSql}`;
        }

        await conn.commit();
        conn.release();
        
        res.status(201).json({ 
            message: 'Complaint registered successfully.', 
            complaintId,
            sql: `START TRANSACTION;\n${insertComplaintSql}${evLogged}\nCOMMIT;\n-- Note: Trigger "trg_after_complaint_insert" fired automatically on Complaints table.`
        });
    } catch (err) {
        if (conn) {
            await conn.rollback();
            conn.release();
        }
        res.status(400).json({ error: err.message, sql: 'START TRANSACTION; ... ROLLBACK;' });
    }
});

// Update Complaint Status (Officer/Admin)
app.put('/api/complaints/:id', async (req, res) => {
    const { id } = req.params;
    const { status, remarks, changedBy, changedById } = req.body;
    
    const updateSql = 'UPDATE Complaints SET Status = ?, UpdatedAt = CURRENT_TIMESTAMP() WHERE ComplaintID = ?;';
    const insertHistSql = 'INSERT INTO StatusHistory (ComplaintID, Status, ChangedBy, ChangedByID, Remarks) VALUES (?, ?, ?, ?, ?);';
    
    let conn;
    try {
        conn = await pool.getConnection();
        await conn.beginTransaction();
        
        // 1. Update complaints status (fires trg_after_complaint_status_update)
        await conn.execute(updateSql, [status, id]);

        // 2. Insert custom officer notes
        let histLogged = '';
        if (remarks) {
            await conn.execute(insertHistSql, [id, status, changedBy, changedById, remarks]);
            histLogged = `\n${insertHistSql}`;
        }

        await conn.commit();
        conn.release();
        
        res.json({ 
            message: 'Case status updated successfully.',
            sql: `START TRANSACTION;\n${updateSql}${histLogged}\nCOMMIT;\n-- Note: Trigger "trg_after_complaint_status_update" fired automatically to log transition.`
        });
    } catch (err) {
        if (conn) {
            await conn.rollback();
            conn.release();
        }
        res.status(400).json({ error: err.message, sql: 'START TRANSACTION; ... ROLLBACK;' });
    }
});


// --- ADMIN MANAGEMENT APIS ---

// Add new Officer (Admin)
app.post('/api/officers', async (req, res) => {
    const { fullName, badgeNumber, rank, email, phone, department } = req.body;
    const sql = 'INSERT INTO Officers (FullName, BadgeNumber, Rank, Email, PasswordHash, Phone, Department) VALUES (?, ?, ?, ?, ?, ?, ?);';
    try {
        await pool.execute(sql, [fullName, badgeNumber, rank, email, 'hashed_password_dummy', phone, department]);
        res.status(201).json({ message: 'Officer added successfully.', sql });
    } catch (err) {
        res.status(400).json({ error: err.message, sql });
    }
});

// Assign complaint to officer (Admin)
app.post('/api/assignments', async (req, res) => {
    const { complaintId, officerId, adminId, remarks } = req.body;
    
    const deactivateSql = "UPDATE Assignments SET Status = 'Reassigned' WHERE ComplaintID = ? AND Status = 'Active';";
    const assignSql = 'INSERT INTO Assignments (ComplaintID, OfficerID, AssignedByAdminID, Remarks) VALUES (?, ?, ?, ?);';
    
    let conn;
    try {
        conn = await pool.getConnection();
        await conn.beginTransaction();
        
        // 1. Deactivate old assignments
        await conn.execute(deactivateSql, [complaintId]);
        
        // 2. Insert new assignment (triggers trg_after_assignment_insert which sets complaints status to 'Assigned')
        await conn.execute(assignSql, [complaintId, officerId, adminId, remarks]);
        
        await conn.commit();
        conn.release();
        
        res.status(201).json({ 
            message: 'Case assigned successfully.', 
            sql: `START TRANSACTION;\n${deactivateSql}\n${assignSql}\nCOMMIT;\n-- Note: Trigger "trg_after_assignment_insert" automatically updated Complaint status to "Assigned".`
        });
    } catch (err) {
        if (conn) {
            await conn.rollback();
            conn.release();
        }
        res.status(400).json({ error: err.message, sql: 'START TRANSACTION; ... ROLLBACK;' });
    }
});

// Get all officers
app.get('/api/officers', async (req, res) => {
    const sql = 'SELECT OfficerID, FullName, BadgeNumber, Rank, Email, Phone, Department FROM Officers ORDER BY FullName ASC;';
    try {
        const [rows] = await pool.query(sql);
        res.json({ data: rows, sql });
    } catch (err) {
        res.status(500).json({ error: err.message, sql });
    }
});


// --- REPORT & METRIC APIS ---

// Get Officer Workloads (from v_officer_workload View)
app.get('/api/reports/workloads', async (req, res) => {
    const sql = 'SELECT * FROM v_officer_workload;';
    try {
        const [rows] = await pool.query(sql);
        res.json({ data: rows, sql });
    } catch (err) {
        res.status(500).json({ error: err.message, sql });
    }
});

// Get Crime Stats (from v_crime_statistics View)
app.get('/api/reports/crime-stats', async (req, res) => {
    const sql = 'SELECT * FROM v_crime_statistics;';
    try {
        const [rows] = await pool.query(sql);
        res.json({ data: rows, sql });
    } catch (err) {
        res.status(500).json({ error: err.message, sql });
    }
});

// Get complaint audit history logs
app.get('/api/complaints/:id/history', async (req, res) => {
    const { id } = req.params;
    const sql = 'SELECT * FROM StatusHistory WHERE ComplaintID = ? ORDER BY ChangedAt ASC;';
    try {
        const [rows] = await pool.execute(sql, [id]);
        res.json({ data: rows, sql });
    } catch (err) {
        res.status(500).json({ error: err.message, sql });
    }
});

// Get case evidence records
app.get('/api/complaints/:id/evidence', async (req, res) => {
    const { id } = req.params;
    const sql = 'SELECT * FROM Evidence WHERE ComplaintID = ? ORDER BY UploadedAt ASC;';
    try {
        const [rows] = await pool.execute(sql, [id]);
        res.json({ data: rows, sql });
    } catch (err) {
        res.status(500).json({ error: err.message, sql });
    }
});


// --- SQL LABORATORY EXECUTOR ---

app.post('/api/sql/run', async (req, res) => {
    const { query } = req.body;
    if (!query || typeof query !== 'string') {
        return res.status(400).json({ error: 'Query must be a valid string.' });
    }
    
    try {
        const trimmed = query.trim();
        const firstWord = trimmed.split(/\s+/)[0].toUpperCase();
        
        const [rows, fields] = await pool.query(trimmed);
        
        if (Array.isArray(rows)) {
            // It is a SELECT query returning records
            const columns = fields ? fields.map(f => f.name) : (rows.length > 0 ? Object.keys(rows[0]) : []);
            res.json({ type: 'select', columns, rows, sql: query });
        } else {
            // It is an INSERT/UPDATE/DELETE statement returning operation details
            res.json({ type: 'write', message: `Statement executed successfully. Affected rows: ${rows.affectedRows || 0}`, sql: query });
        }
    } catch (err) {
        res.status(400).json({ error: err.message });
    }
});


// =====================================================================
// SERVER LAUNCH (With dynamic port fallback)
// =====================================================================
async function start() {
    await initializeDatabase();
    
    function startServer(port) {
        const server = app.listen(port, () => {
            console.log(`================================================================`);
            console.log(`Cyber Crime Complaint Management System SQL Server Active.`);
            console.log(`Listening on: http://localhost:${port}`);
            console.log(`Press Ctrl+C to stop.`);
            console.log(`================================================================`);
        });
        
        server.on('error', (err) => {
            if (err.code === 'EADDRINUSE') {
                console.log(`Port ${port} is in use, trying next port ${port + 1}...`);
                startServer(port + 1);
            } else {
                console.error('Server error:', err);
            }
        });
    }
    
    startServer(PORT);
}

start();
