CREATE DATABASE SubjectAllot

USE SubjectAllot


CREATE TABLE StudentDetails
(
  StudentId INT PRIMARY KEY,
  StudentName VARCHAR(255),
  GPA FLOAT,
  Branch VARCHAR(255),
  Section VARCHAR(20)
)

CREATE TABLE SubjectDetail
(
   SubjectId VARCHAR(255) PRIMARY KEY,
   SubjectName VARCHAR(255),
   MaxSeats INT,
   RemainingSeats INT
)

EXEC sp_rename 'SubjectDetails.Subjectd',  'SubjectId', 'COLUMN';


CREATE TABLE StudentPreference
(
  StudentId INT,
  SubjectId VARCHAR(255),
  Preference INT,
  FOREIGN KEY(StudentId) REFERENCES StudentDetails(StudentId),
  FOREIGN KEY(SubjectId) REFERENCES SubjectDetail(SubjectId)
)


INSERT INTO StudentDetails
VALUES(159103036,'Mohit Agarwal',8.9,'CCE','A'),
      (159103037,'Rohit Agarwal',5.2,'CCE','A'),
	  (159103038,'Shohit Garg',7.1,'CCE','B'),
	  (159103039,'Mrinal Malhotra',7.9,'CCE','A'),
	  (159103040,'Mehrit Singh',5.6,'CCE','A'),
	  (159103041,'Arjun Tehlan',9.2,'CCE','B')

INSERT INTO SubjectDetail
VALUES('P01491','Basics of Political Science',60,2),
      ('P01492','Basics of Accounting',120,119),
	  ('P01493','Basics of Financial Markets',90,90),
	  ('P01494','Eco Philosophy',60,50),
	  ('P01495','Automotive Trends',60,60)

INSERT INTO StudentPreference     --for 1st student
VALUES(159103036,'P01491',1),
      (159103036,'P01492',2),
	  (159103036,'P01493',3),
	  (159103036,'P01494',4),
	  (159103036,'P01495',5)

INSERT INTO StudentPreference ---for last student
VALUES(159103041,'P01491',4),
      (159103041,'P01492',2),
	  (159103041,'P01493',3),
	  (159103041,'P01494',1),
	  (159103041,'P01495',5)

SELECT * FROM StudentPreference

SELECT * FROM StudentPreference
SELECT * FROM SubjectDetail
SELECT * FROM StudentDetails

SELECT sp.SubjectId,sp.StudentId
FROM StudentPreference sp
ORDER BY sp.Preference 





--create temporary tables
CREATE TABLE #RankedStudents (
    StudentId INT,
    GPA FLOAT,
    Rank INT
);

CREATE TABLE #RankedPreferences (
    StudentId INT,
    SubjectId NVARCHAR(10),
    Preference INT,
    Rank INT
);

CREATE TABLE #AvailableSeats (
    SubjectId NVARCHAR(10),
    MaxSeats INT,
    RemainingSeats INT
);

CREATE TABLE #TempAllotments (
    SubjectId NVARCHAR(10),
    StudentId INT
);

CREATE TABLE #TempUnallottedStudents (
    StudentId INT PRIMARY KEY
);


 
--Insert data
INSERT INTO #RankedStudents (StudentId, GPA, Rank)
SELECT
    StudentId,
    GPA,
    ROW_NUMBER() OVER (ORDER BY GPA DESC) AS Rank
FROM StudentDetails;

INSERT INTO #RankedPreferences (StudentId, SubjectId, Preference, Rank)
SELECT
    StudentId,
    SubjectId,
    Preference,
    ROW_NUMBER() OVER (PARTITION BY StudentId ORDER BY Preference) AS Rank
FROM StudentPreference;

INSERT INTO #AvailableSeats (SubjectId, MaxSeats, RemainingSeats)
SELECT
    SubjectId,
    MaxSeats,
    MaxSeats AS RemainingSeats
FROM SubjectDetail;

SELECT * FROM #RankedStudents
SELECT * FROM #AvailableSeats
SELECT * FROM #RankedPreferences
SELECT * FROM #TempAllotments
SELECT * FROM #TempUnallottedStudents



--flow:
--initially take student ids in dec order of rank(gpa) choose each student
--for each student ids check their subjectid from increasing order of pref for subject
--loop until each student got alloacate



--allocate subjects to students
DECLARE @StudentId INT, @SubjectId NVARCHAR(10), @RemainingSeats INT;  --var for current student

DECLARE Student_cursor CURSOR FOR  --student cursor
SELECT StudentId FROM #RankedStudents ORDER BY Rank;    --ordered students by decr order of Rank

OPEN Student_cursor;
FETCH NEXT FROM Student_cursor INTO @StudentId; --fetches 1st student id

WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE preference_cursor CURSOR FOR   --preference cursor
    SELECT SubjectId FROM #RankedPreferences WHERE StudentId = @StudentId ORDER BY Rank;

    OPEN preference_cursor;
    FETCH NEXT FROM preference_cursor INTO @SubjectId; --fetches 1st subject id of current selected student

    DECLARE @Allocated BIT = 0;    

    WHILE @@FETCH_STATUS = 0 AND @Allocated = 0   --loop continues until there are rows to fetch and students are not allocated
    BEGIN
        SELECT @RemainingSeats = RemainingSeats FROM #AvailableSeats WHERE SubjectId = @SubjectId;

        IF @RemainingSeats > 0
        BEGIN
            -- Allocate subject to the student
            INSERT INTO #TempAllotments (SubjectId, StudentId)
            VALUES (@SubjectId, @StudentId);

            -- Update remaining seats
            UPDATE #AvailableSeats
            SET RemainingSeats = RemainingSeats - 1    --decrements remaining seats for current subj
            WHERE SubjectId = @SubjectId;

            SET @Allocated = 1;   --student has allocated to subject
        END

        FETCH NEXT FROM preference_cursor INTO @SubjectId;  --FETCH NEXT :fetches next subject id if not allocated that subject
    END

    CLOSE preference_cursor;
    DEALLOCATE preference_cursor;

    -- If the student was not allocated any subject, mark as unallotted
    IF @Allocated = 0
    BEGIN
        INSERT INTO #TempUnallottedStudents (StudentId)
        VALUES (@StudentId);
    END

    FETCH NEXT FROM Student_cursor INTO @StudentId; --fetch next studentId if previous got allocated or disallocated
END

CLOSE Student_cursor;     --cursor is closed--disassociates cursor from result set but retains curs definition
DEALLOCATE Student_cursor; --removes cursor definition and releases all associated resources

--insert results

create table Allotments
(
   SubjectId Varchar(255),
   StudentId Int
)
create table UnallottedStudents
(
   StudentId Int
)

INSERT INTO Allotments (SubjectId, StudentId)
SELECT DISTINCT SubjectId, StudentId FROM #TempAllotments;

INSERT INTO UnallottedStudents(StudentId)
SELECT DISTINCT StudentId FROM #TempUnallottedStudents;

--clean up temp tables
DROP TABLE #RankedStudents;
DROP TABLE #RankedPreferences;
DROP TABLE #AvailableSeats;
DROP TABLE #TempAllotments;
DROP TABLE #TempUnallottedStudents;

select * from Allotments

select * from UnallottedStudents


