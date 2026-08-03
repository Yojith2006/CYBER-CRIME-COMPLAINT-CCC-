-- =====================================================================
-- DATABASE SCHEMA: Cyber Crime Complaint Management System
-- Database Engine: MySQL / MariaDB (Fully standard SQL compatible)
-- Description: Schema DDL defining Tables, Relationships, Constraints, 
--              Views, Triggers, and Indexes for the college project.
-- =====================================================================

-- Drop existing views and tables in reverse dependency order to start fresh
DROP VIEW IF EXISTS v_crime_statistics;
DROP VIEW IF EXISTS v_officer_workload;
DROP VIEW IF EXISTS v_complaint_details;
DROP TABLE IF EXISTS StatusHistory;
DROP TABLE IF EXISTS Evidence;
DROP TABLE IF EXISTS Assignments;
DROP TABLE IF EXISTS Complaints;
DROP TABLE IF EXISTS Admins;
DROP TABLE IF EXISTS Officers;
DROP TABLE IF EXISTS Users;
DROP TABLE IF EXISTS CrimeTypes;

-- =====================================================================
-- 1. TABLE DEFINITIONS (MySQL Syntax)
-- =====================================================================

-- Table: CrimeTypes
CREATE TABLE CrimeTypes (
    CrimeTypeID INT AUTO_INCREMENT PRIMARY KEY,
    TypeName VARCHAR(100) UNIQUE NOT NULL,
    Description TEXT,
    SeverityLevel VARCHAR(10) NOT NULL,
    CONSTRAINT chk_severity CHECK (SeverityLevel IN ('Low', 'Medium', 'High', 'Critical'))
);

-- Table: Users (Citizens)
CREATE TABLE Users (
    UserID INT AUTO_INCREMENT PRIMARY KEY,
    FullName VARCHAR(100) NOT NULL,
    Email VARCHAR(100) UNIQUE NOT NULL,
    PasswordHash VARCHAR(255) NOT NULL,
    Phone VARCHAR(15) NOT NULL,
    AadhaarNumber CHAR(12) UNIQUE NOT NULL,
    Address TEXT NOT NULL,
    CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_aadhaar CHECK (LENGTH(AadhaarNumber) = 12)
);

-- Table: Officers
CREATE TABLE Officers (
    OfficerID INT AUTO_INCREMENT PRIMARY KEY,
    FullName VARCHAR(100) NOT NULL,
    BadgeNumber VARCHAR(20) UNIQUE NOT NULL,
    OfficerRank VARCHAR(50) NOT NULL,
    Email VARCHAR(100) UNIQUE NOT NULL,
    PasswordHash VARCHAR(255) NOT NULL,
    Phone VARCHAR(15) NOT NULL,
    Department VARCHAR(100) NOT NULL,
    CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Table: Admins
CREATE TABLE Admins (
    AdminID INT AUTO_INCREMENT PRIMARY KEY,
    FullName VARCHAR(100) NOT NULL,
    Email VARCHAR(100) UNIQUE NOT NULL,
    PasswordHash VARCHAR(255) NOT NULL,
    Phone VARCHAR(15) NOT NULL,
    CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Table: Complaints
CREATE TABLE Complaints (
    ComplaintID INT AUTO_INCREMENT PRIMARY KEY,
    UserID INT NOT NULL,
    CrimeTypeID INT NOT NULL,
    Title VARCHAR(200) NOT NULL,
    Description TEXT NOT NULL,
    DateOfOccurrence DATE NOT NULL,
    Location VARCHAR(255) NOT NULL,
    Status VARCHAR(30) DEFAULT 'Pending' NOT NULL,
    CreatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    UpdatedAt DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (UserID) REFERENCES Users(UserID) ON DELETE CASCADE,
    FOREIGN KEY (CrimeTypeID) REFERENCES CrimeTypes(CrimeTypeID),
    CONSTRAINT chk_status CHECK (Status IN ('Pending', 'Assigned', 'Under Investigation', 'Evidence Gathered', 'Resolved', 'Closed'))
);

-- Table: Assignments
CREATE TABLE Assignments (
    AssignmentID INT AUTO_INCREMENT PRIMARY KEY,
    ComplaintID INT NOT NULL,
    OfficerID INT NOT NULL,
    AssignedByAdminID INT NOT NULL,
    AssignedDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    Status VARCHAR(20) DEFAULT 'Active' NOT NULL,
    Remarks TEXT,
    FOREIGN KEY (ComplaintID) REFERENCES Complaints(ComplaintID) ON DELETE CASCADE,
    FOREIGN KEY (OfficerID) REFERENCES Officers(OfficerID) ON DELETE CASCADE,
    FOREIGN KEY (AssignedByAdminID) REFERENCES Admins(AdminID),
    CONSTRAINT chk_assign_status CHECK (Status IN ('Active', 'Completed', 'Reassigned'))
);

-- Table: Evidence
CREATE TABLE Evidence (
    EvidenceID INT AUTO_INCREMENT PRIMARY KEY,
    ComplaintID INT NOT NULL,
    FileName VARCHAR(255) NOT NULL,
    FilePath VARCHAR(500) NOT NULL,
    FileType VARCHAR(50) NOT NULL,
    FileSizeKB INT NOT NULL,
    UploadedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    Description TEXT,
    FOREIGN KEY (ComplaintID) REFERENCES Complaints(ComplaintID) ON DELETE CASCADE,
    CONSTRAINT chk_filesize CHECK (FileSizeKB > 0)
);

-- Table: StatusHistory
CREATE TABLE StatusHistory (
    HistoryID INT AUTO_INCREMENT PRIMARY KEY,
    ComplaintID INT NOT NULL,
    Status VARCHAR(30) NOT NULL,
    ChangedBy VARCHAR(20) DEFAULT 'System' NOT NULL,
    ChangedByID INT DEFAULT 0,
    Remarks TEXT,
    ChangedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ComplaintID) REFERENCES Complaints(ComplaintID) ON DELETE CASCADE,
    CONSTRAINT chk_actor CHECK (ChangedBy IN ('User', 'Officer', 'Admin', 'System'))
);


-- =====================================================================
-- 2. INDEXES FOR PERFORMANCE OPTIMIZATION
-- =====================================================================
CREATE INDEX idx_complaints_user ON Complaints(UserID);
CREATE INDEX idx_complaints_status ON Complaints(Status);
CREATE INDEX idx_complaints_crimetype ON Complaints(CrimeTypeID);
CREATE INDEX idx_assignments_officer_active ON Assignments(OfficerID, Status);


-- =====================================================================
-- 3. SQL VIEWS (MySQL Syntax)
-- =====================================================================

-- View: v_complaint_details
CREATE VIEW v_complaint_details AS
SELECT 
    c.ComplaintID,
    c.Title,
    c.Description,
    ct.TypeName AS CrimeType,
    ct.SeverityLevel,
    c.DateOfOccurrence,
    c.Location,
    c.Status,
    c.CreatedAt AS ComplaintDate,
    u.FullName AS CitizenName,
    u.Email AS CitizenEmail,
    u.Phone AS CitizenPhone,
    o.FullName AS AssignedOfficer,
    o.BadgeNumber AS OfficerBadge,
    a.AssignedDate,
    a.Remarks AS AssignmentRemarks
FROM Complaints c
INNER JOIN Users u ON c.UserID = u.UserID
INNER JOIN CrimeTypes ct ON c.CrimeTypeID = ct.CrimeTypeID
LEFT JOIN Assignments a ON c.ComplaintID = a.ComplaintID AND a.Status = 'Active'
LEFT JOIN Officers o ON a.OfficerID = o.OfficerID;

-- View: v_officer_workload
CREATE VIEW v_officer_workload AS
SELECT 
    o.OfficerID,
    o.FullName AS OfficerName,
    o.BadgeNumber,
    o.OfficerRank,
    COUNT(CASE WHEN c.Status NOT IN ('Resolved', 'Closed') AND a.Status = 'Active' THEN 1 END) AS ActiveCasesCount,
    COUNT(CASE WHEN c.Status = 'Resolved' THEN 1 END) AS ResolvedCasesCount,
    COUNT(CASE WHEN c.Status = 'Closed' THEN 1 END) AS ClosedCasesCount,
    COUNT(a.AssignmentID) AS TotalCasesAssigned
FROM Officers o
LEFT JOIN Assignments a ON o.OfficerID = a.OfficerID
LEFT JOIN Complaints c ON a.ComplaintID = c.ComplaintID
GROUP BY o.OfficerID, o.FullName, o.BadgeNumber, o.OfficerRank;

-- View: v_crime_statistics
CREATE VIEW v_crime_statistics AS
SELECT 
    ct.CrimeTypeID,
    ct.TypeName AS CrimeType,
    ct.SeverityLevel,
    COUNT(c.ComplaintID) AS TotalComplaints,
    COUNT(CASE WHEN c.Status = 'Pending' THEN 1 END) AS PendingComplaints,
    COUNT(CASE WHEN c.Status IN ('Assigned', 'Under Investigation', 'Evidence Gathered') THEN 1 END) AS ActiveComplaints,
    COUNT(CASE WHEN c.Status IN ('Resolved', 'Closed') THEN 1 END) AS SolvedComplaints,
    ROUND(COUNT(CASE WHEN c.Status IN ('Resolved', 'Closed') THEN 1 END) * 100.0 / NULLIF(COUNT(c.ComplaintID), 0), 2) AS ResolutionRatePercent
FROM CrimeTypes ct
LEFT JOIN Complaints c ON ct.CrimeTypeID = c.CrimeTypeID
GROUP BY ct.CrimeTypeID, ct.TypeName, ct.SeverityLevel;


-- =====================================================================
-- 4. DATABASE TRIGGERS (MySQL Syntax)
-- Note: MySQL requires DELIMITER command to wrap trigger definitions.
-- =====================================================================

DELIMITER //

-- Trigger: trg_after_complaint_insert
CREATE TRIGGER trg_after_complaint_insert
AFTER INSERT ON Complaints
FOR EACH ROW
BEGIN
    INSERT INTO StatusHistory (ComplaintID, Status, ChangedBy, ChangedByID, Remarks)
    VALUES (NEW.ComplaintID, 'Pending', 'User', NEW.UserID, 'Complaint registered successfully by the citizen.');
END //

-- Trigger: trg_after_complaint_status_update
CREATE TRIGGER trg_after_complaint_status_update
AFTER UPDATE ON Complaints
FOR EACH ROW
BEGIN
    IF OLD.Status <> NEW.Status THEN
        INSERT INTO StatusHistory (ComplaintID, Status, ChangedBy, ChangedByID, Remarks)
        VALUES (
            NEW.ComplaintID,
            NEW.Status,
            'System',
            0,
            CONCAT('Complaint status changed from "', OLD.Status, '" to "', NEW.Status, '".')
        );
    END IF;
END //

-- Trigger: trg_after_assignment_insert
CREATE TRIGGER trg_after_assignment_insert
AFTER INSERT ON Assignments
FOR EACH ROW
BEGIN
    UPDATE Complaints
    SET Status = 'Assigned', UpdatedAt = CURRENT_TIMESTAMP
    WHERE ComplaintID = NEW.ComplaintID;
END //

DELIMITER ;
