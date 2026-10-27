WITH JobRuns AS
(
    SELECT
        j.name                                              AS JobName,
        msdb.dbo.agent_datetime(h.run_date, h.run_time)     AS StartTime,
        (h.run_duration / 10000) * 3600
          + (h.run_duration / 100 % 100) * 60
          + (h.run_duration % 100)                          AS DurationSeconds,
        h.run_status,
        h.message
    FROM msdb.dbo.sysjobhistory AS h
    JOIN msdb.dbo.sysjobs       AS j ON j.job_id = h.job_id
    WHERE h.step_id = 0
)
SELECT
    JobName,
    StartTime,
    DATEADD(SECOND, DurationSeconds, StartTime)             AS EndTime,
    DurationSeconds,
    CONCAT(DurationSeconds / 3600, ':',
           RIGHT('0' + CAST(DurationSeconds / 60 % 60 AS varchar(2)), 2), ':',
           RIGHT('0' + CAST(DurationSeconds % 60 AS varchar(2)), 2)) AS Duration_hhmmss,
    CASE run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
        WHEN 4 THEN 'In Progress'
    END                                                     AS Outcome,
    message
FROM JobRuns
WHERE DATEADD(SECOND, DurationSeconds, StartTime) >= DATEADD(HOUR, -24, GETDATE())
ORDER BY EndTime DESC;