-- =====================================================================
-- SQL QUERY PACKAGE: Cyber Crime Complaint Management System
-- Database Engine: MySQL / MariaDB (Fully standard SQL compatible)
-- Description: Structured SQL queries categorized by complexity,
--              demonstrating MySQL query features for evaluation.
-- =====================================================================

-- =====================================================================
-- PART 1: BASIC QUERIES (SELECT, WHERE, ORDER BY, LIMIT)
-- =====================================================================

-- Query 1.1: Retrieve all registered citizens, ordered alphabetically by name
SELECT UserID, FullName, Email, Phone, CreatedAt 
FROM Users 
ORDER BY FullName ASC;

-- Query 1.2: Find all crime types classified as High or Critical severity
SELECT CrimeTypeID, TypeName, SeverityLevel 
FROM CrimeTypes 
WHERE SeverityLevel IN ('High', 'Critical')
ORDER BY SeverityLevel DESC;

-- Query 1.3: Find complaints filed in New Delhi
SELECT ComplaintID, Title, DateOfOccurrence, Status 
FROM Complaints 
WHERE Location = 'New Delhi'
ORDER BY DateOfOccurrence DESC;


-- =====================================================================
-- PART 2: JOINS (Combining Multi-Table Information)
-- =====================================================================

-- Query 2.1: Retrieve all complaints with citizen details and crime category names
-- Complexity: 3-Table Join (Complaints, Users, CrimeTypes)
SELECT 
    c.ComplaintID, 
    c.Title, 
    u.FullName AS CitizenName, 
    ct.TypeName AS CrimeCategory, 
    c.Status, 
    c.CreatedAt
FROM Complaints c
INNER JOIN Users u ON c.UserID = u.UserID
INNER JOIN CrimeTypes ct ON c.CrimeTypeID = ct.CrimeTypeID
ORDER BY c.CreatedAt DESC;

-- Query 2.2: Retrieve active case assignments showing assigned officer details
-- Complexity: 3-Table Join with Filter (Assignments, Complaints, Officers)
SELECT 
    a.AssignmentID, 
    c.ComplaintID, 
    c.Title AS ComplaintTitle, 
    o.FullName AS AssignedOfficer, 
    o.OfficerRank, 
    a.AssignedDate, 
    a.Remarks
FROM Assignments a
INNER JOIN Complaints c ON a.ComplaintID = c.ComplaintID
INNER JOIN Officers o ON a.OfficerID = o.OfficerID
WHERE a.Status = 'Active'
ORDER BY a.AssignedDate DESC;

-- Query 2.3: Retrieve all evidence records along with complaint and citizen details
-- Complexity: 4-Table Join (Evidence, Complaints, Users, CrimeTypes)
SELECT 
    e.EvidenceID,
    e.FileName,
    e.FileType,
    e.FileSizeKB,
    c.Title AS CaseTitle,
    u.FullName AS OwnerName,
    u.Email AS OwnerEmail
FROM Evidence e
INNER JOIN Complaints c ON e.ComplaintID = c.ComplaintID
INNER JOIN Users u ON c.UserID = u.UserID
ORDER BY e.EvidenceID ASC;


-- =====================================================================
-- PART 3: AGGREGATIONS & GROUP BY (Summary and Metrics)
-- =====================================================================

-- Query 3.1: Count total complaints filed under each crime type
SELECT 
    ct.TypeName AS CrimeCategory, 
    COUNT(c.ComplaintID) AS TotalComplaints
FROM CrimeTypes ct
LEFT JOIN Complaints c ON ct.CrimeTypeID = c.CrimeTypeID
GROUP BY ct.CrimeTypeID, ct.TypeName
ORDER BY TotalComplaints DESC;

-- Query 3.2: Calculate the total evidence size (in MB) uploaded per complaint
-- Complexity: Join, Group By, HAVING filter, Mathematical calculations
SELECT 
    c.ComplaintID, 
    c.Title AS ComplaintTitle, 
    COUNT(e.EvidenceID) AS TotalEvidenceFiles,
    ROUND(SUM(e.FileSizeKB) / 1024.0, 2) AS TotalSizeMB
FROM Complaints c
INNER JOIN Evidence e ON c.ComplaintID = e.ComplaintID
GROUP BY c.ComplaintID, c.Title
HAVING SUM(e.FileSizeKB) > 200
ORDER BY TotalSizeMB DESC;


-- =====================================================================
-- PART 4: SUBQUERIES AND ADVANCED SQL (CTEs, Nested Queries)
-- =====================================================================

-- Query 4.1: Find complaints that have more evidence files than the average across all cases
-- Complexity: Correlated/Uncorrelated Subquery in WHERE
SELECT ComplaintID, Title, Status 
FROM Complaints 
WHERE ComplaintID IN (
    SELECT ComplaintID 
    FROM Evidence 
    GROUP BY ComplaintID 
    HAVING COUNT(EvidenceID) > (
        SELECT AVG(FileCount) 
        FROM (SELECT COUNT(EvidenceID) AS FileCount FROM Evidence GROUP BY ComplaintID) AS SubTable
    )
);

-- Query 4.2: Find officers who have more active assignments than the department average workload
-- Complexity: Common Table Expression (CTE) and subqueries
WITH OfficerWorkloads AS (
    SELECT o.OfficerID, o.FullName, COUNT(a.AssignmentID) AS ActiveCases
    FROM Officers o
    LEFT JOIN Assignments a ON o.OfficerID = a.OfficerID AND a.Status = 'Active'
    GROUP BY o.OfficerID, o.FullName
)
SELECT FullName, ActiveCases
FROM OfficerWorkloads
WHERE ActiveCases > (SELECT AVG(ActiveCases) FROM OfficerWorkloads);

-- Query 4.3: Calculate the resolution duration (in days) for closed complaints (MySQL DATEDIFF)
-- Complexity: Common Table Expression (CTE), Date arithmetic (DATEDIFF), subqueries
WITH CaseResolutions AS (
    SELECT 
        c.ComplaintID,
        c.Title,
        ct.TypeName AS Category,
        DATEDIFF(sh_end.ChangedAt, sh_start.ChangedAt) AS ResolutionDays
    FROM Complaints c
    JOIN CrimeTypes ct ON c.CrimeTypeID = ct.CrimeTypeID
    JOIN StatusHistory sh_start ON c.ComplaintID = sh_start.ComplaintID AND sh_start.Status = 'Pending'
    JOIN StatusHistory sh_end ON c.ComplaintID = sh_end.ComplaintID AND sh_end.Status = 'Closed'
)
SELECT 
    ComplaintID, 
    Title, 
    Category,
    ResolutionDays AS DaysTakenToSolve,
    (SELECT ROUND(AVG(ResolutionDays), 2) FROM CaseResolutions) AS AverageDepartmentDays
FROM CaseResolutions;


-- =====================================================================
-- PART 5: VIEW AND TRIGGER VERIFICATION
-- =====================================================================

-- Query 5.1: Select from v_complaint_details (reporting view)
SELECT ComplaintID, Title, CitizenName, CrimeType, Status, AssignedOfficer 
FROM v_complaint_details;

-- Query 5.2: Select from v_officer_workload (analytics view)
SELECT OfficerName, OfficerRank, ActiveCasesCount, ResolvedCasesCount, ClosedCasesCount, TotalCasesAssigned
FROM v_officer_workload;

-- Query 5.3: Select from v_crime_statistics (dashboard stats view)
SELECT CrimeType, SeverityLevel, TotalComplaints, PendingComplaints, ActiveComplaints, SolvedComplaints, ResolutionRatePercent
FROM v_crime_statistics;

-- Query 5.4: Review the complete audit trail (Status History Log) for Complaint ID 1
SELECT Status, ChangedBy, Remarks, ChangedAt 
FROM StatusHistory 
WHERE ComplaintID = 1 
ORDER BY ChangedAt ASC;
