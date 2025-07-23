USE [AUTOMATIC_BI_PRO]
GO
/****** Object:  StoredProcedure [dbo].[SP_AUTOMATIC_BI_NC_IMP]    Script Date: 22/07/2025 4:12:27 p. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--Procedimiento para traer el detallado de los atributos de los preoperacionales con no conformidades.
ALTER PROCEDURE [dbo].[SP_AUTOMATIC_BI_NC_IMP]
        @BDNAME VARCHAR(MAX)
	   ,@FILTROS VARCHAR(MAX) = ''
	   ,@PERIODO VARCHAR (30) = 'VIGENCIA'
	   ,@CENTROCOSTO VARCHAR(MAX) = '*'
    
As BEGIN

 SET NOCOUNT ON

    DECLARE @GENERICO VARCHAR(10) = '''-'''
	       ,@RESUMEN VARCHAR (10)
	       ,@CICLO  VARCHAR(100)	
	       ,@DIAS VARCHAR (5)
	       ,@FECINI As DATE = '2022-01-01'
		   ,@QUERY VARCHAR(MAX) = ''
		   ,@UNION VARCHAR(10) = ''
		   --,@PERIODO VARCHAR (30) = 'VIGENCIA'

	SET @PERIODO = UPPER(@PERIODO)

	IF (@PERIODO = 'VIGENCIA')
		set @FECINI = DATEFROMPARTS(YEAR(GETDATE()),1,1)
	ELSE IF (@PERIODO = 'ANUAL')
		set @FECINI = DATEADD(YEAR,-1,GETDATE())
	ELSE IF (@PERIODO = 'TRIMESTRE')
		set @FECINI = CAST(DATEADD(MONTH,-3,GETDATE()) As DATE)
	ELSE IF (@PERIODO = 'MES')
		set @FECINI = DATEADD(MONTH,-1,GETDATE())
	ELSE IF (@PERIODO = 'ULTIMOS3AÑOS')
		SET @FECINI = '2023-07-01'
	ELSE IF (@PERIODO = 'BIMESTRE')
		set @FECINI = DATEADD(DD,-DATEDIFF(DAY,DATEADD(MONTH,DATEDIFF(MONTH,0,GETDATE())-1,0),GETDATE()),GETDATE())
	ELSE
		set @FECINI = DATEADD(WEEK,-1,GETDATE())

	SET @PERIODO = UPPER(LTRIM(RTRIM(@PERIODO)))
	
	IF (@PERIODO = 'ANUAL') OR (@PERIODO = 'TRIMESTRE') OR (@PERIODO = 'BIMESTRE') OR (@PERIODO = 'VIGENCIA') OR (@PERIODO = 'VIGENCIA_ANTERIOR') OR (@PERIODO = 'DIARIO') OR (@PERIODO = 'ULTIMOS3AÑOS')
	BEGIN
		SET @RESUMEN = '''Mes'''
		SET @CICLO = 'MONTH(ISNULL(ncd.FechaDocumento,d.FechaFinalEjecucion))'

		IF (@PERIODO = 'ANUAL') 
			SET @DIAS = '365'
		ELSE IF (@PERIODO = 'BIMESTRE')
			SET @DIAS = DATEDIFF(day,DATEADD(DD,-DATEDIFF(DAY,DATEADD(MONTH,DATEDIFF(MONTH,0,GETDATE())-1,0),GETDATE()),GETDATE()),GETDATE())
		ELSE IF (@PERIODO = 'VIGENCIA')
			SET @DIAS = DATEDIFF(day,DATEADD(yy, DATEDIFF(yy, 0, GETDATE()), 0),GETDATE())
		ELSE IF (@PERIODO = 'ULTIMOS3AÑOS')
			SET @DIAS = CAST(DATEDIFF(DAY, '2023-07-01', GETDATE()) AS VARCHAR(10))
		ELSE IF (@PERIODO = 'VIGENCIA_ANTERIOR')
			SET @DIAS = DATEDIFF(day, DATEADD(yy, DATEDIFF(yy, 0, GETDATE()) - 1, 0), GETDATE())
		ELSE IF (@PERIODO = 'DIARIO')
			SET @DIAS = 0
		ELSE
			SET @DIAS = '92'
	END
	ELSE
	BEGIN
		IF @PERIODO = 'MES' 
		BEGIN
			SET @RESUMEN = '''Semana'''
			SET @CICLO = 'DATEPART(Week, ISNULL(ncd.FechaDocumento,d.FechaFinalEjecucion))'
			SET @DIAS = '31'
		END 
		ELSE
		BEGIN
			SET @RESUMEN = '''Dia'''
			SET @CICLO = 'DAY(ISNULL(ncd.FechaDocumento,d.FechaFinalEjecucion))'
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
		[Número NC] VARCHAR(255) COLLATE Modern_Spanish_CI_AS -- Cambia el tipo de datos según sea necesario
		,CentroCostos VARCHAR(255)
		,[Condiciones Tecnicas] VARCHAR(MAX)
		,Resultado VARCHAR(20)
		,Categoria  VARCHAR(MAX)
		,NombreTipoDocumento VARCHAR(MAX)
		,NroIdentificacion VARCHAR(20)
		,NombreUsuarioCreador VARCHAR(400)
		,[Codigo a quien se le detecto] VARCHAR(20)
		,[Nombre a quien se le detecto] VARCHAR(500)
		,[Estado NC] VARCHAR(200)
	);
	PRINT('Días calculados:')
	PRINT(@DIAS)
	-- Insertar los resultados del procedimiento almacenado en la tabla temporal
	DECLARE @campos VARCHAR(MAX) = '
									[Número NC]
									,ISNULL(CASE WHEN LEN([Codigo Proyecto])< 4 THEN CONCAT(''0'',[Codigo Proyecto]) ELSE [Codigo Proyecto] END,''Sin Proyecto'') CentroCostos
									,LOWER([Pregunta NC]) [Condiciones Tecnicas]
									,''NC'' Resultado
									,[Campo NC] Categoria
									,[Tipo Inspección Origen NC] NombreTipoDocumento
									,[Codigo Detector] NroIdentificacion
									,[Nombre del Detector] NombreUsuarioCreador
									,[Codigo a quien se le detecto]
									,[Nombre a quien se le detecto]
									,[Estado] As [Estado NC]
									'
		,@whereClause NVARCHAR(MAX) = N'WHERE D2.IdTipoDocumento IN (20157,20072,20089,20090,20098,20088,20113,20114,20106,20111,20102,20103,20104,20125,20126,20128,20153,20130,20131,20148,20149,20150,20147,20151,20152,20122,20123,20124,20099,20100,20101,20107,20108,20109,20073,20105,20110,20170) 
										AND DATEDIFF(day,D.FechaCreacion,GETDATE()) <= ' + CAST(@DIAS AS NVARCHAR(10));

	INSERT INTO #Temp_ReporteNoConformidades
	EXEC TEMIS_004_PRO.dbo.SP_ReporteNoConformidadesJO @campos,@whereClause
	;

	SELECT RNC.*
		,CAST(D2.FechaFinalEjecucion As DATE) FechaFinalEjecucion
	FROM #Temp_ReporteNoConformidades RNC
	INNER JOIN TEMIS_004_PRO.dbo.Documento D3 ON RNC.[Número NC] = D3.NroDocumento
	INNER JOIN TEMIS_004_PRO.dbo.DocumentoCampoAdicional DCA ON DCA.IdDocumento = D3.IdDocumento
	INNER JOIN TEMIS_004_PRO.dbo.Documento D2 ON D2.IdDocumento = DCA.IdDocumentoOrigenRC
	WHERE RNC.Categoria IS NOT NULL AND RNC.Categoria <> '' -- Filtrar NC sin categoría
	;

	DROP TABLE #Temp_ReporteNoConformidades;

END;

--EXEC SP_AUTOMATIC_BI_NC_IMP '004','','ULTIMOS3AÑOS'