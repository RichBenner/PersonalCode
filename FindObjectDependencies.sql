/*
Fantastic tool from Michael J Swart

http://michaeljswart.com/2018/10/uncovering-hidden-complexity/
*/

DECLARE @object_name SYSNAME = 'Sales.SalesOrderDetail';
 
WITH dependencies AS
(
    SELECT @object_name AS [object_name],
           CAST(
             QUOTENAME(OBJECT_SCHEMA_NAME(OBJECT_ID(@object_name))) + '.' + 
             QUOTENAME(OBJECT_NAME(OBJECT_ID(@object_name)))
             as sysname) as [escaped_name],
           [type_desc],
           object_id(@object_name) AS [object_id],
           1 AS is_updated,
           CAST('/' + CAST(object_id(@object_name) % 10000 as VARCHAR(30)) + '/' AS hierarchyid) as tree,
           0 as trigger_parent_id
      FROM sys.objects 
     WHERE object_id = object_id(@object_name)
 
    UNION ALL
 
    SELECT CAST(OBJECT_SCHEMA_NAME(o.[object_id]) + '.' + OBJECT_NAME(o.[object_id]) as sysname),
           CAST(QUOTENAME(OBJECT_SCHEMA_NAME(o.[object_id])) + '.' + QUOTENAME(OBJECT_NAME(o.[object_id])) as sysname),
           o.[type_desc],
           o.[object_id],
           CASE o.[type] when 'U' then re.is_updated else 1 end,
           CAST(d.tree.ToString() + CAST(o.[object_id] % 10000 as VARCHAR(30)) + '/' AS hierarchyid),
           0 as trigger_parent_id
      FROM dependencies d
     CROSS APPLY sys.dm_sql_referenced_entities(d.[escaped_name], default) re
      JOIN sys.objects o
           ON o.object_id = isnull(re.referenced_id, object_id(ISNULL(re.referenced_schema_name,'dbo') + '.' + re.referenced_entity_name))
     WHERE tree.GetLevel() < 10
       AND re.referenced_minor_id = 0
       AND o.[object_id] <> d.trigger_parent_id
       AND CAST(d.tree.ToString() as varchar(1000)) not like '%' + CAST(o.[object_id] % 10000 as varchar(1000)) + '%'
 
     UNION ALL
 
     SELECT CAST(OBJECT_SCHEMA_NAME(t.[object_id]) + '.' + OBJECT_NAME(t.[object_id]) as sysname),
            CAST(QUOTENAME(OBJECT_SCHEMA_NAME(t.[object_id])) + '.' + QUOTENAME(OBJECT_NAME(t.[object_id])) as sysname),
            'SQL_TRIGGER',
            t.[object_id],
            0 AS is_updated,
            CAST(d.tree.ToString() + CAST(t.object_id % 10000 as VARCHAR(30)) + '/' AS hierarchyid),
            t.parent_id as trigger_parent_id
       FROM dependencies d
       JOIN sys.triggers t
            ON d.[object_id] = t.parent_id
      WHERE d.is_updated = 1
        AND tree.GetLevel() < 10
        AND CAST(d.tree.ToString() as varchar(1000)) not like '%' + cast(t.[object_id] % 10000 as varchar(1000)) + '%'
)
SELECT replicate('—', tree.GetLevel() - 1) + ' ' + [object_name] AS Object_Name, 
       [type_desc] AS Object_Type,
       tree.ToString() AS Dependencies       
  FROM dependencies
 ORDER BY tree
