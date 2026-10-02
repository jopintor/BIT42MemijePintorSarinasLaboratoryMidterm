/* =====================================================================
   Online Campus Event Management System - SQL Server (T-SQL) schema, 3NF
   Run in SSMS / Azure Data Studio, or: sqlcmd -S localhost -i schema.sql
   ===================================================================== */
IF DB_ID(N'CampusEventDB') IS NULL CREATE DATABASE CampusEventDB;
GO
USE CampusEventDB;
GO

-- Re-runnable: drop child tables first
IF OBJECT_ID(N'dbo.Registrations', N'U') IS NOT NULL DROP TABLE dbo.Registrations;
IF OBJECT_ID(N'dbo.Events',        N'U') IS NOT NULL DROP TABLE dbo.Events;
IF OBJECT_ID(N'dbo.Venues',        N'U') IS NOT NULL DROP TABLE dbo.Venues;
IF OBJECT_ID(N'dbo.Users',         N'U') IS NOT NULL DROP TABLE dbo.Users;
GO

CREATE TABLE dbo.Users (
    UserId    INT IDENTITY(1,1) NOT NULL,
    FullName  NVARCHAR(100) NOT NULL,
    Email     NVARCHAR(255) NOT NULL,
    Role      NVARCHAR(10)  NOT NULL CONSTRAINT DF_Users_Role DEFAULT (N'Student'),
    CreatedAt DATETIME2(0)  NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Users PRIMARY KEY CLUSTERED (UserId),
    CONSTRAINT UQ_Users_Email UNIQUE (Email),
    CONSTRAINT CK_Users_Role  CHECK (Role IN (N'Student', N'Admin')),
    CONSTRAINT CK_Users_Email CHECK (Email LIKE N'_%@univ.edu.ph')
);

CREATE TABLE dbo.Venues (
    VenueId   INT IDENTITY(1,1) NOT NULL,
    VenueName NVARCHAR(100) NOT NULL,
    Location  NVARCHAR(200) NULL,
    CONSTRAINT PK_Venues PRIMARY KEY CLUSTERED (VenueId),
    CONSTRAINT UQ_Venues_VenueName UNIQUE (VenueName)
);

CREATE TABLE dbo.Events (
    EventId       INT IDENTITY(1,1) NOT NULL,
    Title         NVARCHAR(150) NOT NULL,
    Description   NVARCHAR(1000) NULL,
    VenueId       INT NOT NULL,
    StartDateTime DATETIME2(0) NOT NULL,
    EndDateTime   DATETIME2(0) NOT NULL,
    Capacity      INT NOT NULL,
    Status        NVARCHAR(10) NOT NULL CONSTRAINT DF_Events_Status DEFAULT (N'Open'),
    CONSTRAINT PK_Events PRIMARY KEY CLUSTERED (EventId),
    CONSTRAINT FK_Events_Venues FOREIGN KEY (VenueId) REFERENCES dbo.Venues (VenueId)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_Events_Capacity CHECK (Capacity > 0),
    CONSTRAINT CK_Events_Dates    CHECK (EndDateTime > StartDateTime),
    CONSTRAINT CK_Events_Status   CHECK (Status IN (N'Open', N'Closed', N'Cancelled'))
);

CREATE TABLE dbo.Registrations (
    RegistrationId INT IDENTITY(1,1) NOT NULL,
    UserId         INT NOT NULL,
    EventId        INT NOT NULL,
    RegisteredAt   DATETIME2(0) NOT NULL CONSTRAINT DF_Reg_RegisteredAt DEFAULT (SYSUTCDATETIME()),
    Status         NVARCHAR(12) NOT NULL CONSTRAINT DF_Reg_Status DEFAULT (N'Confirmed'),
    CONSTRAINT PK_Registrations PRIMARY KEY CLUSTERED (RegistrationId),
    CONSTRAINT FK_Registrations_Users  FOREIGN KEY (UserId)  REFERENCES dbo.Users (UserId)
        ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT FK_Registrations_Events FOREIGN KEY (EventId) REFERENCES dbo.Events (EventId)
        ON DELETE NO ACTION ON UPDATE NO ACTION,   -- cancel events via Status; never delete history
    CONSTRAINT UQ_Registrations_User_Event UNIQUE (UserId, EventId),  -- no double booking
    CONSTRAINT CK_Registrations_Status CHECK (Status IN (N'Confirmed', N'Cancelled', N'Waitlisted'))
);
GO

/* Non-clustered indexes on every foreign key column */
CREATE NONCLUSTERED INDEX IX_Events_VenueId        ON dbo.Events (VenueId);
CREATE NONCLUSTERED INDEX IX_Registrations_UserId  ON dbo.Registrations (UserId);
CREATE NONCLUSTERED INDEX IX_Registrations_EventId ON dbo.Registrations (EventId)
    INCLUDE (UserId, Status, RegisteredAt);   -- covers the admin "attendees per event" query
GO

/* ---------- Sample data ---------- */
INSERT INTO dbo.Users (FullName, Email, Role) VALUES
 (N'Ana Reyes',    N'ana.reyes@univ.edu.ph',    N'Student'),
 (N'Ben Cruz',     N'ben.cruz@univ.edu.ph',     N'Student'),
 (N'Admin Santos', N'admin.santos@univ.edu.ph', N'Admin');
INSERT INTO dbo.Venues (VenueName, Location) VALUES
 (N'University Gym', N'Main Campus'), (N'Room 402', N'IT Building');
INSERT INTO dbo.Events (Title, VenueId, StartDateTime, EndDateTime, Capacity) VALUES
 (N'Intramurals Opening Ceremony', 1, '2026-11-03T08:00', '2026-11-03T11:00', 300),
 (N'Cybersecurity Awareness Talk', 2, '2026-11-10T13:30', '2026-11-10T16:00', 40);
INSERT INTO dbo.Registrations (UserId, EventId) VALUES (1, 2), (2, 2), (1, 1);
GO

/* ---------- Admin query: attendees per event ---------- */
SELECT e.Title, u.FullName, u.Email, r.RegisteredAt
FROM dbo.Registrations r
JOIN dbo.Users  u ON u.UserId  = r.UserId
JOIN dbo.Events e ON e.EventId = r.EventId
WHERE r.Status = N'Confirmed'
ORDER BY e.Title, u.FullName;
GO
