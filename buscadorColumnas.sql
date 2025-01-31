-- Script para encontrar columnas específicas en todas las tablas de la base de datos
-- Útil para mapear relaciones y explorar bases de datos sin documentación

CREATE PROCEDURE dbo.buscarColumnas
	@nombreColumna VARCHAR(MAX) = ''
	,@nombreTabla VARCHAR(MAX) = ''
    --> USO es EXEC dbo.buscarColumnas 'ind_movto','470'
AS
	BEGIN
		SET NOCOUNT ON;

		DECLARE @consulta VARCHAR(MAX) = ''
		SET @consulta = '

		SELECT 
			SCHEMA_NAME(t.schema_id) AS SchemaName,
			t.name AS TableName,
			c.name AS ColumnName,
			ty.name AS DataType,
			c.max_length AS MaxLength,
			c.is_nullable AS IsNullable,
			CASE 
				WHEN EXISTS (
					SELECT 1 FROM sys.index_columns ic 
					JOIN sys.indexes i ON ic.object_id = i.object_id AND ic.index_id = i.index_id
					WHERE ic.object_id = t.object_id AND ic.column_id = c.column_id 
					AND i.is_primary_key = 1
				) THEN ''PK''
				WHEN fk.parent_column_id IS NOT NULL THEN ''FK''
				ELSE NULL
			END AS KeyType,
			OBJECT_NAME(fk.referenced_object_id) AS ReferencedTable
		FROM 
			sys.tables t
			INNER JOIN sys.columns c ON t.object_id = c.object_id
			INNER JOIN sys.types ty ON c.user_type_id = ty.user_type_id
			LEFT JOIN sys.foreign_key_columns fk ON 
				t.object_id = fk.parent_object_id AND
				c.column_id = fk.parent_column_id
		WHERE 
			c.name LIKE ''%'+@nombreColumna+'%'+'''
			'+CASE WHEN @nombreTabla = '' THEN '' ELSE 'and t.name like ''%'+@nombreTabla+'%'' ' END +'
		ORDER BY 
			SchemaName, TableName;
		'

		PRINT(@consulta)
		EXEC(@consulta)

	END;
