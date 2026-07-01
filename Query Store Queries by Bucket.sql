DECLARE @hours_back INT = 24
	,@bucket_size int = 50
	,@back_time datetime
	,@bucket_max int

SELECT @back_time = DATEADD(HOUR, -@hours_back, GETUTCDATE())
	  ,@bucket_max = @bucket_size - 1

IF OBJECT_ID('tempdb..#rsi') IS NOT NULL DROP TABLE #rsi;
SELECT
	 rsi.runtime_stats_interval_id
	,rsi.start_time
	,rsi.end_time
INTO #rsi
FROM sys.query_store_runtime_stats_interval rsi
WHERE rsi.start_time >= @back_time

IF OBJECT_ID('tempdb..#qs_data') IS NOT NULL DROP TABLE #qs_data;
;WITH XMLNAMESPACES ('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS sp)
SELECT
    qt.query_sql_text,
    q.query_id,
    p.plan_id,
    p.is_parallel_plan,
    -- FIX 1: CAST query_plan (nvarchar) to xml before calling .value()
    TRY_CAST(TRY_CAST(p.query_plan AS xml).value('(//sp:StmtSimple/@StatementSubTreeCost)[1]','float') AS float) AS estimated_cost,
	p.query_plan as query_plan,
    rs.count_executions,
    rs.avg_duration / 1000.0							AS avg_duration_ms,
    rs.avg_cpu_time / 1000.0							AS avg_cpu_ms,
    (rs.avg_cpu_time * rs.count_executions) / 1000.0	AS total_cpu_ms,
    rs.avg_logical_io_reads								AS avg_logical_reads,
    rs.avg_dop,
    rs.min_dop,
    rs.max_dop,
    rsi.start_time										AS interval_start,
    rsi.end_time										AS interval_end
INTO #qs_data
FROM #rsi rsi
JOIN sys.query_store_runtime_stats	rs	WITH (NOLOCK)	ON rsi.runtime_stats_interval_id = rs.runtime_stats_interval_id
JOIN sys.query_store_plan			p	WITH (NOLOCK)	ON rs.plan_id                    = p.plan_id
JOIN sys.query_store_query			q	WITH (NOLOCK)	ON p.query_id                    = q.query_id
JOIN sys.query_store_query_text		qt	WITH (NOLOCK)	ON qt.query_text_id              = q.query_text_id

;WITH bucketed AS (
	SELECT
	    *,
        ISNULL(estimated_cost, 0)                          AS cost,
        FLOOR(ISNULL(estimated_cost, 0) / @bucket_size) * @bucket_size         AS cost_bucket_start
	FROM #qs_data
)
SELECT
    CONCAT(cost_bucket_start, ' - ', cost_bucket_start + CONVERT(VARCHAR, @bucket_max))		AS cost_bucket,
    COUNT(DISTINCT query_id)																AS distinct_queries,
    COUNT(DISTINCT plan_id)																	AS distinct_plans,
    SUM(count_executions)																	AS total_executions,
    MIN(cost)																				AS min_estimated_cost,
    MAX(cost)																				AS max_estimated_cost,
    AVG(cost)																				AS avg_estimated_cost,
    SUM(CASE WHEN is_parallel_plan = 1 THEN 1 ELSE 0 END)									AS parallel_plans,
    SUM(CASE WHEN is_parallel_plan = 0 THEN 1 ELSE 0 END)									AS serial_plans,
    MIN(min_dop)																			AS min_dop_seen,
    MAX(max_dop)																			AS max_dop_seen,
    SUM(avg_dop * count_executions) / NULLIF(SUM(count_executions), 0)						AS weighted_avg_dop,
    SUM(CASE WHEN avg_dop = 1              THEN 1 ELSE 0 END)								AS dop_1_serial,
    SUM(CASE WHEN avg_dop BETWEEN 2 AND 4  THEN 1 ELSE 0 END)								AS dop_2_4,
    SUM(CASE WHEN avg_dop BETWEEN 5 AND 8  THEN 1 ELSE 0 END)								AS dop_5_8,
    SUM(CASE WHEN avg_dop BETWEEN 9 AND 16 THEN 1 ELSE 0 END)								AS dop_9_16,
    SUM(CASE WHEN avg_dop > 16             THEN 1 ELSE 0 END)								AS dop_17plus,
    AVG(avg_duration_ms)																	AS avg_duration_ms,
    AVG(avg_cpu_ms)																			AS avg_cpu_ms,
    SUM(total_cpu_ms)																		AS total_cpu_ms,
    AVG(avg_logical_reads)																	AS avg_logical_reads
FROM bucketed
GROUP BY cost_bucket_start
ORDER BY cost_bucket_start;