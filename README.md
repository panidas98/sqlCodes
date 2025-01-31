# SQL Server Column Finder

Este procedimiento almacenado es una herramienta esencial para analistas de datos que trabajan con bases de datos SQL Server, especialmente cuando se enfrentan a bases de datos grandes o sin documentación adecuada.

## Descripción

El script crea un procedimiento almacenado `sp_FindColumn` que permite buscar cualquier columna en todas las tablas de la base de datos. Es particularmente útil cuando:

- Necesitas encontrar relaciones entre tablas
- Trabajas con una base de datos sin documentación
- Buscas identificar tablas relacionadas por nombres de columnas similares
- Necesitas mapear la estructura de la base de datos

## Características

- Busca columnas por nombre (búsqueda parcial incluida)
- Muestra el esquema y nombre de la tabla donde se encuentra la columna
- Identifica el tipo de dato de la columna
- Indica si la columna es nullable
- Identifica si la columna es Primary Key (PK) o Foreign Key (FK)
- Muestra la tabla referenciada en caso de ser una Foreign Key
- Resultados ordenados por esquema y tabla para fácil lectura

## Uso

```sql
-- Ejemplo 1: Buscar todas las columnas que contengan "ID"
EXEC dbo.buscarColumnas 'ID'

-- Ejemplo 2: Buscar todas las columnas relacionadas con "fecha"
EXEC dbo.buscarColumnas 'fecha'

-- Ejemplo 3: Buscar columnas específicas como "un" en la tabla "351"
EXEC dbo.buscarColumnas 'un','351'
```
![image](https://github.com/user-attachments/assets/b7c0da18-ce38-4b96-8933-818c060ecb7a)

## Resultados

El procedimiento retorna una tabla con las siguientes columnas:
- SchemaName: Nombre del esquema
- TableName: Nombre de la tabla
- ColumnName: Nombre de la columna encontrada
- DataType: Tipo de dato de la columna
- MaxLength: Longitud máxima (si aplica)
- IsNullable: Indica si la columna acepta valores NULL
- KeyType: Indica si es PK o FK
- ReferencedTable: Tabla referenciada en caso de ser FK

## Requerimientos

- SQL Server 2008 R2 o superior
- Permisos de lectura sobre los catálogos del sistema
