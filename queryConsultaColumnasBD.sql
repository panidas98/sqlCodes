/*
Esta consulta te dice en cuáles tablas existen cuáles columnas, cuando se necesita saber ubicaciones de columnas para analizar relaciones.
*/

SELECT 
    t.name AS TableName,
    c.name AS ColumnName
FROM 
    sys.columns c
INNER JOIN 
    sys.tables t ON c.object_id = t.object_id
WHERE 
    c.name LIKE '%rowid_auxiliar%'
		and t.name like '%_co_%' ;