-- Script para encontrar columnas específicas en todas las tablas de la base de datos
-- Útil para mapear relaciones y explorar bases de datos sin documentación

-- Busca todas las tablas que contienen una columna con un nombre específico
CREATE PROCEDURE sp_FindColumn
    @ColumnName NVARCHAR(128)
AS
BEGIN
    SELECT 
        SCHEMA_NAME(t.schema_id) AS SchemaName,
        t.name AS TableName,
        c.name AS ColumnName,
        ty.name AS DataType,
        c.max_length AS MaxLength,
        c.is_nullable AS IsNullable,
        CASE 
            WHEN pk.COLUMN_NAME IS NOT NULL THEN 'PK'
            WHEN fk.COLUMN_NAME IS NOT NULL THEN 'FK'
            ELSE NULL
        END AS KeyType,
        OBJECT_NAME(fk.referenced_object_id) AS ReferencedTable
    FROM 
        sys.tables t
        INNER JOIN sys.columns c ON t.object_id = c.object_id
        INNER JOIN sys.types ty ON c.user_type_id = ty.user_type_id
        LEFT JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE pk ON 
            t.name = pk.TABLE_NAME AND 
            c.name = pk.COLUMN_NAME AND
            pk.CONSTRAINT_NAME LIKE 'PK%'
        LEFT JOIN sys.foreign_key_columns fk ON 
            t.object_id = fk.parent_object_id AND
            c.column_id = fk.parent_column_id
    WHERE 
        c.name LIKE '%' + @ColumnName + '%'
    ORDER BY 
        SchemaName, TableName;
END;