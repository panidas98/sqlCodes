USE [AUTOMATIC_BI_PRO]
GO
/****** Object:  StoredProcedure [dbo].[SP_AUTOMATIC_BI_ResumenInspeccionesTEST]    Script Date: 22/07/2025 3:22:12 p. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =========================================================
-- Author:		Juan Esteban Ochoa Echeverri
-- Create date: 09/06/2023
-- Description:	Resumen mensual de las inspecciones de campo
-- LastUpdate: 13/09/2024
-- Motivo: Contemplar NC repetidas por medio del SP generado 1058 desde Implementaciones.
-- =========================================================

/* Importador para obtener un resumen por mes de los preoperacionales realizados con su número de conformidades y no conformidades */
ALTER PROCEDURE [dbo].[SP_AUTOMATIC_BI_ResumenInspeccionesTEST]

        @BDNAME VARCHAR(30)
	   ,@SP_FILTRO VARCHAR(MAX)
	   ,@PERIODO VARCHAR (20) = 'ANUAL'  -- Aumentado de 10 a 20 para 'ULTIMOS3AÑOS'
	   ,@FILTROS VARCHAR(MAX)

As 
 BEGIN

 /*Definición de parámetros*/
 DECLARE @GENERICO VARCHAR(10) = '''-'''
	       ,@RESUMEN VARCHAR (10)
	       ,@CICLO  VARCHAR(200)	
	       ,@DIAS VARCHAR (5)
	       ,@FECINI As DATE = '2023-01-01'
		   ,@QUERY VARCHAR(MAX)
		   ,@MESINICIO VARCHAR(200) = 'DATEADD(DAY, 1, EOMONTH(CAST(d.FechaDocumento As DATE),-1))' --'DATEADD(DAY, 1, EOMONTH(CAST(CASE WHEN d.codigo = ''0005'' THEN DATEADD(HH, 6, d.FechaFinalEjecucion) else d.FechaFinalEjecucion END As DATE),-1))'
		   
	SET @PERIODO = UPPER(@PERIODO)

	IF (@PERIODO = 'VIGENCIA')
		SET @FECINI = DATEFROMPARTS(YEAR(GETDATE()), 1, 1)
	ELSE IF (@PERIODO = 'ANUAL')
		SET @FECINI = DATEADD(YEAR, -1, GETDATE())
	ELSE IF (@PERIODO = 'TRIMESTRE')
		SET @FECINI = DATEADD(MONTH, -3, GETDATE())
	ELSE IF (@PERIODO = 'MES')
		SET @FECINI = DATEADD(MONTH, -1, GETDATE())
	ELSE IF (@PERIODO = 'ULTIMOS3AÑOS')
		SET @FECINI = '2023-07-01'
	ELSE
		SET @FECINI = DATEADD(WEEK, -1, GETDATE())


	SET @PERIODO = UPPER(LTRIM(RTRIM(@PERIODO)))
	
	IF (@PERIODO = 'ANUAL') OR (@PERIODO = 'TRIMESTRE') OR (@PERIODO = 'ULTIMOS3AÑOS') BEGIN
	
		SET @RESUMEN = '''Mes'''

	-- Para todos los períodos, usamos la misma lógica de diferencia de días
	SET @CICLO = 'DATEDIFF(day,CASE WHEN p2.idproyecto = 10131 THEN CONVERT(DATE, DATEADD(HH, 6, d.FechaDocumento)) ELSE CONVERT(DATE,d.FechaDocumento) END,GETDATE())'
	
	IF (@PERIODO = 'ANUAL') BEGIN
		SET @DIAS = '365'
	END
	ELSE IF (@PERIODO = 'ULTIMOS3AÑOS') BEGIN
		SET @DIAS = CAST(DATEDIFF(DAY, '2023-07-01', GETDATE()) AS VARCHAR(10)) -- Calculamos exactamente los días desde 2023-07-01
	END
	ELSE BEGIN
		SET @DIAS = '92'
	END
		
	END ELSE BEGIN
				
		IF @PERIODO = 'MES' BEGIN
		
			SET @RESUMEN = '''Semana'''
			SET @CICLO = 'DATEPART(Week, CASE WHEN p2.idproyecto = 10131 THEN dateadd(HH, 6, d.FechaFinalEjecucion) else d.FechaFinalEjecucion END)'
			SET @DIAS = '31'
		
		END ELSE BEGIN
			
			SET @RESUMEN = '''Dia'''
			SET @CICLO = 'DAY(CASE WHEN p2.idproyecto = 10131 THEN dateadd(HH, 6, d.FechaFinalEjecucion) else d.FechaFinalEjecucion END)'
			SET @DIAS = '7'
		
		END
    END;

	/*=======================================================================================================*/
	/* AGREGAMOS LOS DOCUMENTOS DE NC CORRECTOS PARA PODER EXCLUIRLOS DE LOS CONTEOS RELACIONADOS CON LAS NC */

	-- Verificar si la tabla temporal ya existe y eliminarla si es necesario
	IF OBJECT_ID('tempdb..#Temp_ReporteNoConformidades') IS NOT NULL
		DROP TABLE #Temp_ReporteNoConformidades;

	-- Crear una tabla temporal
	CREATE TABLE #Temp_ReporteNoConformidades (
		[Número NC] VARCHAR(255) COLLATE Modern_Spanish_CI_AS, -- Cambia el tipo de datos según sea necesario
		Categoria VARCHAR(MAX) COLLATE Modern_Spanish_CI_AS -- Agregar columna Categoria para filtrar
	);

	-- Insertar los resultados del procedimiento almacenado en la tabla temporal
	DECLARE @campos VARCHAR(MAX) = '[Número NC], [Campo NC] AS Categoria' -- Incluir Categoria en los campos
		,@whereClause NVARCHAR(MAX) = N'WHERE D2.IdTipoDocumento IN (20157,20072,20089,20090,20098,20088,20113,20114,20106,20111,20102,20103,20104,20125,20126,20128,20153,20130,20131,20148,20149,20150,20147,20151,20152,20122,20123,20124,20099,20100,20101,20107,20108,20109,20073,20105,20110,20170) 
										AND DATEDIFF(day,D.FechaCreacion,GETDATE()) <= ' + @DIAS; -- Usar @DIAS en lugar de 792 fijo
	INSERT INTO #Temp_ReporteNoConformidades
	EXEC TEMIS_004_PRO.dbo.SP_ReporteNoConformidadesJO @campos,@whereClause

	-- Aplicar el mismo filtro de categoría que en el script 2
	DELETE FROM #Temp_ReporteNoConformidades 
	WHERE Categoria IS NULL OR Categoria = ''

	/*=======================================================================================================*/

	/*==============================================INICIO CONSULTA==========================================*/
	SET @QUERY = '

	USE '+@BDNAME+';
	SET NOCOUNT ON;
  
	WITH PO_Doc as (
	  SELECT D.Iddocumento
			,d.NroDocumento
			,p2.Codigo
			,DCA.IdServicioSolicitado 
			,TD.NombreTipoDocumento
			,d.FechaDocumento
			,d.IdUsuarioCreador
	  FROM [TEMIS_004_PRO].dbo.Documento d
		LEFT JOIN [TEMIS_004_PRO].dbo.DocumentoCampoAdicional DCA ON D.IdDocumento = dca.IdDocumento  
		LEFT JOIN [TEMIS_004_PRO].dbo.Proyecto P2 ON dca.IdProyecto = P2.IdProyecto
		INNER JOIN [TEMIS_004_PRO].dbo.TipoDocumento td ON d.IdTipoDocumento = td.IdTipoDocumento'+
		CASE WHEN (@FILTROS = '') THEN ' WHERE ' ELSE ' WHERE '+ @FILTROS +' AND ' END 
		+@CICLO+' <= '+@DIAS+'
	),
	tecnicos As (
		SELECT '+@MESINICIO+' MesFinalEjecución
			,p2.Codigo
			,COUNT(DISTINCT sb.CodigoSubBodega) empleadosInspeccionados
		FROM [TEMIS_004_PRO].dbo.documento d --PO_Doc d
		LEFT JOIN [TEMIS_004_PRO].dbo.DocumentoCampoAdicional DCA ON D.IdDocumento = dca.IdDocumento  
		LEFT JOIN [TEMIS_004_PRO].dbo.Proyecto P2 ON dca.IdProyecto = P2.IdProyecto
		-- Tecnico al que le hacen la inspección----------
		LEFT JOIN [TEMIS_004_PRO].dbo.OrdenSubBodega osb 
			ON osb.IdDocumento = d.IdDocumento 
				AND osb.RecursoMaterial = 0
		LEFT JOIN [TEMIS_004_PRO].dbo.SubBodega sb 
			ON sb.IdSubBodega = osb.IdSubBodega
		--------------------------------------------------
		WHERE '+ @CICLO + ' <= '+@DIAS+'
		GROUP BY DATEADD(DAY, 1, EOMONTH(CAST(d.FechaDocumento As DATE),-1))
		,p2.Codigo
	)

	  /*Tabla Resumen consolidando conteo de inspecciones, conformidades y no conformidades*/
	  SELECT '+
			@MESINICIO+' MesFinalEjecución
			--,d.NroDocumento
			,NombreTipoDocumento [ServicioSolicitado]
			,e2.NroIdentificacion [Codigo Inspector]
			,CASE WHEN da.[Atributo15] = '' '' OR da.[Atributo15] IS NULL THEN ''Inmediata'' ELSE da.[Atributo15] END TipoInspeccion
			,CASE
				WHEN (CASE WHEN LEN(ISNULL(d.Codigo, ''N/A''))< 4 THEN CONCAT(''0'',ISNULL(d.Codigo, ''N/A'')) ELSE ISNULL(d.Codigo, ''N/A'') END) = ''0009'' THEN ''P009''
				ELSE (CASE WHEN LEN(ISNULL(d.Codigo, ''N/A''))< 4 THEN CONCAT(''0'',ISNULL(d.Codigo, ''N/A'')) ELSE ISNULL(d.Codigo, ''N/A'') END)
				END AS [CentroCostos]
			,COUNT(d.iddocumento) [NroInspecciones]
			,SUM(NroNoConformidadesCerradas) NroNoConformidadesCerradas
			,SUM(NroConformidades) NroConformidades
			,SUM(NroNoConformidades) NroNoConformidades
			,SUM(NroNoConformidadesAbiertaCorreccion) NroNoConformidadesAbiertaCorreccion
			,SUM(NroNoConformidadesAbiertaSinCorreccion) NroNoConformidadesAbiertaSinCorreccion
			,tec.empleadosInspeccionados empleadosInspeccionados
		FROM PO_Doc d
		LEFT JOIN [TEMIS_004_PRO].dbo.DocumentoCampoAdicional DCA ON DCA.IdDocumento = d.IdDocumento
		LEFT JOIN [TEMIS_004_PRO].dbo.ServicioSolicitado ss	ON ss.IdServicioSolicitado = d.IdServicioSolicitado
		LEFT JOIN(SELECT d.Iddocumento
						,CASE WHEN dnc.IdDocumentoEstado = 16 THEN COUNT(DISTINCT dnc.NroDocumento) ELSE 0 END NroNoConformidadesCerradas
						,CASE WHEN dnc.IdDocumentoEstado = 17 THEN COUNT(DISTINCT dnc.NroDocumento) ELSE 0 END NroNoConformidadesAbiertaCorreccion
						,CASE WHEN dnc.IdDocumentoEstado = 15 THEN COUNT(DISTINCT dnc.NroDocumento) ELSE 0 END NroNoConformidadesAbiertaSinCorreccion
						,SUM(CASE WHEN dcanc.IdDocumentoOrigenRC IS NULL THEN 1 ELSE 0 END) NroConformidades
						,COUNT(DISTINCT dnc.NroDocumento) NroNoConformidades
					FROM PO_Doc d
					LEFT JOIN [TEMIS_004_PRO].dbo.OrdenSubBodega osb ON osb.IdDocumento = d.IdDocumento AND osb.RecursoMaterial = 0
					LEFT JOIN [TEMIS_004_PRO].dbo.SubBodega sb ON sb.IdSubBodega = osb.IdSubBodega
					LEFT JOIN [TEMIS_004_PRO].dbo.DocumentoCampoAdicional dcanc ON dcanc.IdDocumentoOrigenRC = d.IdDocumento --and sb.IdEmpleado = dcanc.IdEmpleadoResponsable
					LEFT JOIN [TEMIS_004_PRO].dbo.Documento dnc ON dcanc.IdDocumento = dnc.IdDocumento --and dnc.IdDocumento = dcanc.IdDocumento
					INNER JOIN #Temp_ReporteNoConformidades NC_Correcta ON dnc.NroDocumento = NC_Correcta.[Número NC] --> dejamos solo las NC correctas
					GROUP BY d.Iddocumento,dnc.IdDocumentoEstado
				 ) NC ON d.IdDocumento = NC.IdDocumento
		LEFT JOIN TEMIS_004_PRO.dbo.DocumentoAtributo da ON d.IdDocumento = da.IdDocumento

		--> JOIN para el inspector
		LEFT JOIN TEMIS_004_PRO.dbo.Usuario u ON d.IdUsuarioCreador = u.IdUsuario
		LEFT JOIN TEMIS_004_PRO.dbo.SubBodega sb2 ON u.IdSubBodega = sb2.IdSubBodega
		LEFT JOIN TEMIS_004_PRO.dbo.Empleado e2 ON sb2.IdEmpleado = e2.IdEmpleado

		--> JOIN para cobertura
		LEFT JOIN tecnicos tec
			ON tec.MesFinalEjecución = DATEADD(DAY, 1, EOMONTH(CAST(d.FechaDocumento As DATE),-1))
				AND tec.Codigo = d.Codigo

		GROUP BY '+
		 @MESINICIO+'
		,d.codigo
		,NombreTipoDocumento
		,CASE WHEN da.[Atributo15] = '' '' OR da.[Atributo15] IS NULL THEN ''Inmediata'' ELSE da.[Atributo15] END
		,e2.NroIdentificacion
		,tec.empleadosInspeccionados
		--,d.NroDocumento
		ORDER BY ISNULL(CASE WHEN LEN(d.codigo)< 4 THEN CONCAT(''0'',d.codigo) ELSE d.codigo END,''Sin Proyecto'')
	'
	/*==============================================FIN CONSULTA==========================================*/

	PRINT(@QUERY)
	EXEC(@QUERY)

	-- Eliminar la tabla temporal
	DROP TABLE #Temp_ReporteNoConformidades;
  
END;