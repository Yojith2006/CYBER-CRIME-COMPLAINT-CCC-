-- =====================================================================
-- SEED DATA: Cyber Crime Complaint Management System
-- Database Engine: MySQL / MariaDB
-- Description: DML Insert statements to populate the database tables
--              with realistic records for academic demonstration.
-- =====================================================================

-- Temporarily disable foreign keys to allow table truncation
SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE StatusHistory;
TRUNCATE TABLE Evidence;
TRUNCATE TABLE Assignments;
TRUNCATE TABLE Complaints;
TRUNCATE TABLE Admins;
TRUNCATE TABLE Officers;
TRUNCATE TABLE Users;
TRUNCATE TABLE CrimeTypes;

-- Re-enable foreign key constraints
SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- 1. INSERT CRIME TYPES
-- =====================================================================
INSERT INTO CrimeTypes (TypeName, Description, SeverityLevel) VALUES 
('Phishing & Social Engineering', 'Fake emails, websites, or messages designed to steal sensitive credentials and financial data.', 'High'),
('Identity Theft', 'Unauthorized acquisition and use of another person\'s personal identity data (Aadhaar, PAN, credentials).', 'High'),
('Online Financial Fraud', 'Unauthorized banking transactions, UPI fraud, credit/debit card cloning, and e-commerce scams.', 'Critical'),
('Ransomware & Malware Attacks', 'Malicious software encrypting user files or locking systems, demanding money to restore access.', 'Critical'),
('Cyberstalking & Harassment', 'Online abuse, stalking, threatening messages, or sharing offensive content targeting individuals.', 'Medium'),
('Hacking & Unauthorized Access', 'Breach of computer networks, personal profiles, or databases without authorization.', 'High'),
('Cyber Defamation', 'Posting false, harmful information on social media or forums to tarnish an individual or brand reputation.', 'Low');

-- =====================================================================
-- 2. INSERT USERS (CITIZENS)
-- =====================================================================
INSERT INTO Users (FullName, Email, PasswordHash, Phone, AadhaarNumber, Address) VALUES
('Ramesh Kumar', 'ramesh.kumar@gmail.com', '$2b$12$K3mFf0eWpZ...hash1', '9876543210', '123456789012', '12, Sector 15, Dwarka, New Delhi - 110075'),
('Priya Sharma', 'priya.sharma@yahoo.com', '$2b$12$SgYp29sDjH...hash2', '9812345678', '987654321098', 'Flat 402, Royal Residency, Andheri West, Mumbai - 400053'),
('Anil Deshmukh', 'anil.desh@gmail.com', '$2b$12$xP2hQ9wLsK...hash3', '8765432109', '456789012345', '78-B, Koregaon Park, Lane 3, Pune - 411001'),
('Sneha Reddy', 'sneha.reddy@outlook.com', '$2b$12$aBc123DeFg...hash4', '7654321098', '789012345678', 'H.No 4-12, Jubilee Hills, Hyderabad - 500033'),
('Vikram Singh', 'vikram.singh@gmail.com', '$2b$12$zXy987wVut...hash5', '6543210987', '345678901234', '15A, Park Street, Kolkata - 700016');

-- =====================================================================
-- 3. INSERT OFFICERS
-- =====================================================================
INSERT INTO Officers (FullName, BadgeNumber, OfficerRank, Email, PasswordHash, Phone, Department) VALUES
('Inspector Rajesh Patil', 'POL-CYB-001', 'Inspector', 'rajesh.patil@cybercrime.gov.in', '$2b$12$uY8tR7eWq...hash6', '9900887766', 'Cyber Forensics Unit'),
('Sub-Inspector Amit Verma', 'POL-CYB-002', 'Sub-Inspector', 'amit.verma@cybercrime.gov.in', '$2b$12$iO9p8o7iU...hash7', '9911223344', 'Financial Fraud Division'),
('Sub-Inspector Sunita Rao', 'POL-CYB-003', 'Sub-Inspector', 'sunita.rao@cybercrime.gov.in', '$2b$12$yT6rE5wQ4...hash8', '9922334455', 'Social Media Crimes Cell'),
('DSP Dr. Vivek Bhasin', 'POL-CYB-000', 'Deputy Superintendent of Police', 'vivek.bhasin@cybercrime.gov.in', '$2b$12$qW1eR2tY3...hash9', '9933445566', 'Cyber Crime Investigation HQ');

-- =====================================================================
-- 4. INSERT ADMINS
-- =====================================================================
INSERT INTO Admins (FullName, Email, PasswordHash, Phone) VALUES
('Super Admin Rakesh', 'admin.rakesh@cybercrime.gov.in', '$2b$12$aSdFgHjKl1...hash10', '9000011111'),
('Admin Systems Manager', 'admin.sys@cybercrime.gov.in', '$2b$12$zXcVbNmLk2...hash11', '9000022222');

-- =====================================================================
-- 5. INSERT COMPLAINTS (CITIZENS FILE COMPLAINTS)
-- Note: Trigger 'trg_after_complaint_insert' will fire and automatically 
-- create a 'Pending' entry in StatusHistory for each insert.
-- =====================================================================
INSERT INTO Complaints (UserID, CrimeTypeID, Title, Description, DateOfOccurrence, Location) VALUES
-- Complaint 1: Financial Fraud (Citizen: Ramesh Kumar)
(1, 3, 'Unauthorized Bank Transfer of Rs. 45,000 via Spoofed App', 
'Received a call claiming to be from my bank asking to verify my UPI PIN via a link. Soon after clicking the link, Rs. 45,000 was debited in three transactions of Rs. 15,000 each to a beneficiary named "E-Trade Pay". I did not authorize this.', 
'2026-05-15', 'New Delhi'),

-- Complaint 2: Phishing (Citizen: Priya Sharma)
(2, 1, 'Phishing email posing as Netflix billing update', 
'I received an email stating my Netflix account would be suspended if I did not update billing details immediately. I entered my credit card details on the portal (netflix-billing-verify.net). Later, I noticed minor unauthorized test charges of $1.00 on my credit card. I have blocked the card but want to report the site.', 
'2026-05-18', 'Mumbai'),

-- Complaint 3: Cyberstalking (Citizen: Sneha Reddy)
(4, 5, 'Threatening and Harassing Instagram Account', 
'An anonymous account with handle @user_99281 has been constantly sending abusive messages, threatening to leak photoshopped pictures of me if I do not pay them. I have blocked multiple accounts created by the same person.', 
'2026-05-20', 'Hyderabad'),

-- Complaint 4: Ransomware (Citizen: Vikram Singh)
(5, 4, 'WannaLocker Ransomware encryption on personal PC', 
'My PC files got locked with the extension .locked, and a splash screen demands 0.05 BTC ($3000 approx) to decrypt. I had clicked a link in a resume email yesterday. Important tax documents and family photos are encrypted.', 
'2026-05-24', 'Kolkata'),

-- Complaint 5: Defamation (Citizen: Anil Deshmukh)
(3, 7, 'Fake Defamatory Posts on local Facebook Group', 
'A fake account under the name "Pune Truths" has posted false rumors about my business practices, accusing us of using illegal materials. This is hurting my restaurant\'s reputation severely and is completely baseless.', 
'2026-05-22', 'Pune'),

-- Complaint 6: Financial Fraud (Citizen: Ramesh Kumar)
(1, 3, 'UPI scam offering double returns on Telegram group', 
'Joined a Telegram channel "Double Money Investments". Sent Rs. 10,000 via GPay UPI ID (scamster@okhdfc) expecting double returns. The channel admin blocked me immediately after payment.', 
'2026-05-26', 'New Delhi');

-- =====================================================================
-- 6. INSERT CASE ASSIGNMENTS
-- Note: Trigger 'trg_after_assignment_insert' will fire, which automatically
-- updates the Complaint status to 'Assigned'. This update will then fire 
-- 'trg_after_complaint_status_update', adding an 'Assigned' log to StatusHistory.
-- =====================================================================
INSERT INTO Assignments (ComplaintID, OfficerID, AssignedByAdminID, Remarks) VALUES
-- Assign Complaint 1 (Financial Fraud) to SI Amit Verma (Financial Fraud Division)
(1, 2, 1, 'Assigned to Financial Fraud Division for tracking beneficiary bank details.'),

-- Assign Complaint 3 (Cyberstalking) to SI Sunita Rao (Social Media Crimes Cell)
(3, 3, 1, 'Assigned to Cyberstalking team. Trace IP/Registrant of the Instagram accounts.'),

-- Assign Complaint 4 (Ransomware) to Inspector Rajesh Patil (Cyber Forensics Unit)
(4, 1, 2, 'Assigned to Forensics for decryption attempts and malware strain identification.');

-- =====================================================================
-- 7. PROGRESS CASES TO SIMULATE COMPLAINT PROGRESSION (UPDATE STATUSES)
-- When we update Complaint status, the trigger 'trg_after_complaint_status_update'
-- automatically inserts corresponding audit entries into StatusHistory.
-- =====================================================================

-- Progress Complaint 1 (Financial Fraud) -> 'Under Investigation'
UPDATE Complaints 
SET Status = 'Under Investigation', UpdatedAt = CURRENT_TIMESTAMP()
WHERE ComplaintID = 1;

-- Progress Complaint 3 (Cyberstalking) -> 'Evidence Gathered'
UPDATE Complaints 
SET Status = 'Evidence Gathered', UpdatedAt = CURRENT_TIMESTAMP()
WHERE ComplaintID = 3;

-- Progress Complaint 5 (Defamation, unassigned) -> Admin marks as 'Resolved'
UPDATE Complaints 
SET Status = 'Resolved', UpdatedAt = CURRENT_TIMESTAMP()
WHERE ComplaintID = 5;

-- Close Complaint 5
UPDATE Complaints 
SET Status = 'Closed', UpdatedAt = CURRENT_TIMESTAMP()
WHERE ComplaintID = 5;

-- =====================================================================
-- 8. INSERT EVIDENCE
-- =====================================================================
INSERT INTO Evidence (ComplaintID, FileName, FilePath, FileType, FileSizeKB, Description) VALUES
-- Evidence for Complaint 1 (Ramesh UPI Fraud)
(1, 'screenshot_transaction_details.png', '/uploads/evidence/case_1/screenshot_transaction.png', 'image/png', 245, 'Screenshot of transaction debits from bank mobile application.'),
(1, 'bank_statement_may2026.pdf', '/uploads/evidence/case_1/bank_statement.pdf', 'application/pdf', 1024, 'Official bank statement showing the unauthorized debit entries.'),

-- Evidence for Complaint 2 (Priya Netflix Phishing)
(2, 'netflix_phishing_email.eml', '/uploads/evidence/case_2/phishing_email.eml', 'message/rfc822', 45, 'Raw phishing email file showing sender IP headers.'),
(2, 'phishing_page_screenshot.jpg', '/uploads/evidence/case_2/screenshot_phishing.jpg', 'image/jpeg', 188, 'Screenshot of the fake billing portal.'),

-- Evidence for Complaint 3 (Sneha Cyberstalking)
(3, 'instagram_direct_messages.pdf', '/uploads/evidence/case_3/dm_logs.pdf', 'application/pdf', 512, 'Compiled chat logs and threats received via Instagram DMs.'),

-- Evidence for Complaint 4 (Vikram Ransomware)
(4, 'ransomware_note.txt', '/uploads/evidence/case_4/ransom_instructions.txt', 'text/plain', 5, 'Copy of the ransom note file left on the desktop.');

-- =====================================================================
-- 9. ADD MANUAL DETAILED STATUS HISTORY ENTRIES
-- =====================================================================
INSERT INTO StatusHistory (ComplaintID, Status, ChangedBy, ChangedByID, Remarks) VALUES
(1, 'Under Investigation', 'Officer', 2, 'Sub-Inspector Amit Verma sent notices to bank to freeze beneficiary wallet "E-Trade Pay".'),
(3, 'Evidence Gathered', 'Officer', 3, 'Sub-Inspector Sunita Rao gathered Instagram logs and requested Meta India for IP registration details of target account.'),
(5, 'Resolved', 'Admin', 1, 'Fake Facebook account reported to Meta. Account removed. Citizen informed.'),
(5, 'Closed', 'Admin', 1, 'Citizen verified removal and confirmed satisfaction. Closing case file.');
