DECLARE @JobName SYSNAME = 'Your Job Name Here';

SELECT 
    j.name AS JobName,
    
    -- Convert run_date and run_time into a proper datetime
    msdb.dbo.agent_datetime(h.run_date, h.run_time) AS RunDateTime,
    
    -- Duration formatted as HH:MM:SS
    RIGHT('00' + CAST(h.run_duration / 10000 AS VARCHAR(2)), 2) + ':' +
    RIGHT('00' + CAST((h.run_duration % 10000) / 100 AS VARCHAR(2)), 2) + ':' +
    RIGHT('00' + CAST(h.run_duration % 100 AS VARCHAR(2)), 2) AS Duration,
    
    -- Duration in seconds (useful for sorting/analysis)
    (h.run_duration / 10000) * 3600 +
    ((h.run_duration % 10000) / 100) * 60 +
    (h.run_duration % 100) AS DurationSeconds,
    
    -- Status
    CASE h.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
        WHEN 4 THEN 'In Progress'
    END AS RunStatus

FROM msdb.dbo.sysjobs j
INNER JOIN msdb.dbo.sysjobhistory h 
    ON j.job_id = h.job_id

WHERE j.name = @JobName
    AND h.step_id = 0  -- Only job outcome rows (not individual steps)

ORDER BY RunDateTime DESC;