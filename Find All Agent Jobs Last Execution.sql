SELECT 
    j.name AS JobName,
    j.enabled AS IsEnabled,
    CASE 
        WHEN j.enabled = 1 THEN 'Enabled' 
        ELSE 'Disabled' 
    END AS JobStatusFlag,
    la.run_requested_date AS LastRunDate,
    CASE la.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
        WHEN 4 THEN 'In Progress'
        ELSE 'Unknown'
    END AS LastRunOutcome,
    -- Convert run_duration (HHMMSS int) into a readable duration
    STUFF(STUFF(RIGHT('000000' + CAST(la.run_duration AS VARCHAR(6)), 6), 3, 0, ':'), 6, 0, ':') AS LastRunDuration,
    la.message AS LastRunMessage,
    js.next_run_date,
    js.next_run_time
FROM msdb.dbo.sysjobs j
LEFT JOIN (
    -- Get the most recent run per job from job history (step_id = 0 is the overall job outcome row)
    SELECT 
        job_id,
        run_date,
        run_time,
        run_duration,
        run_status,
        message,
        -- Build a proper datetime from the run_date/run_time ints
        msdb.dbo.agent_datetime(run_date, run_time) AS run_requested_date,
        ROW_NUMBER() OVER (PARTITION BY job_id ORDER BY run_date DESC, run_time DESC) AS rn
    FROM msdb.dbo.sysjobhistory
    WHERE step_id = 0
) la ON la.job_id = j.job_id AND la.rn = 1
LEFT JOIN (
    SELECT job_id, MIN(next_run_date) AS next_run_date, MIN(next_run_time) AS next_run_time
    FROM msdb.dbo.sysjobschedules
    GROUP BY job_id
) js ON js.job_id = j.job_id
ORDER BY j.name;