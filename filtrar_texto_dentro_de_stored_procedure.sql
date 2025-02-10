USE AUTOMATIC_BI_PRO;
SELECT 
    o.name AS procedure_name, 
    m.definition 
FROM sys.sql_modules m
JOIN sys.objects o ON m.object_id = o.object_id
WHERE o.type = 'P' -- Filtra solo procedimientos almacenados
AND m.definition LIKE '%12C%';