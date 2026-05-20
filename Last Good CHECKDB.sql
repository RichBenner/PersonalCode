-- Create a temp table to hold results
IF OBJECT_ID('tempdb..#CheckDBResults') IS NOT NULL
    DROP TABLE #CheckDBResults;

CREATE TABLE #CheckDBResults (
    DatabaseName    NVARCHAR(128),
    LastGoodCheckDB DATETIME,
    DaysSinceCheck  INT,
    Status          NVARCHAR(50)
);

-- Cursor to loop through all online databases
DECLARE @dbname NVARCHAR(128);
DECLARE @sql    NVARCHAR(500);

DECLARE db_cursor CURSOR FAST_FORWARD FOR
    SELECT name
    FROM sys.databases
    WHERE state_desc = 'ONLINE'
    ORDER BY name;

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @dbname;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Temp table for DBCC DBINFO output
    IF OBJECT_ID('tempdb..#DBInfo') IS NOT NULL
        DROP TABLE #DBInfo;

    CREATE TABLE #DBInfo (
        ParentObject VARCHAR(255),
        Object       VARCHAR(255),
        Field        VARCHAR(255),
        Value        VARCHAR(255)
    );

    SET @sql = 'DBCC DBINFO(' + QUOTENAME(@dbname) + ') WITH TABLERESULTS, NO_INFOMSGS;';

    INSERT INTO #DBInfo (ParentObject, Object, Field, Value)
    EXEC (@sql);

    INSERT INTO #CheckDBResults (DatabaseName, LastGoodCheckDB, DaysSinceCheck, Status)
    SELECT
        @dbname,
        CASE WHEN Value = '1900-01-01 00:00:00.000' THEN NULL ELSE CAST(Value AS DATETIME) END,
        CASE WHEN Value = '1900-01-01 00:00:00.000' THEN NULL
             ELSE DATEDIFF(DAY, CAST(Value AS DATETIME), GETDATE()) END,
        CASE WHEN Value = '1900-01-01 00:00:00.000' THEN 'NEVER RUN'
             WHEN DATEDIFF(DAY, CAST(Value AS DATETIME), GETDATE()) > 7  THEN 'WARNING: Overdue'
             ELSE 'OK'
        END
    FROM #DBInfo
    WHERE Field = 'dbi_dbccLastKnownGood';

    FETCH NEXT FROM db_cursor INTO @dbname;
END;

CLOSE db_cursor;
DEALLOCATE db_cursor;

-- Final output
SELECT
    DatabaseName,
    ISNULL(CONVERT(VARCHAR(20), LastGoodCheckDB, 120), 'NEVER') AS LastGoodCheckDB,
    ISNULL(CAST(DaysSinceCheck AS VARCHAR(10)), 'N/A')           AS DaysSinceCheckDB,
    Status
FROM #CheckDBResults
ORDER BY DaysSinceCheck DESC, DatabaseName;

DROP TABLE #CheckDBResults;