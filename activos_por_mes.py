############################################################## AGREGAR CARPETA DE PAQUETES AL PATH ##############################################################
import sys
import os
# Obtén la ruta al directorio principal de tu proyecto
ruta_proyecto = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
# Añade la ruta al directorio principal de tu proyecto a sys.path
sys.path.append(ruta_proyecto)
##################################################################################################################################################################
import pyodbc
import calendar
import pandas as pd
from PythonPackages import sharepoint
from datetime import datetime, timedelta
from PythonPackages.email import send_email
from PythonPackages.sharepoint import upload_analytics_operativos_agh

# Conexión a la base de datos
server = 'OVSAWSSQL01'
database = 'Agh_PRO'
username = 'TemisWeb'
password = '!T3m1sW3b1234'

# Cadena de conexión con autenticación
conn_str = f'DRIVER={{SQL Server}};SERVER={server};DATABASE={database};UID={username};PWD={password}'


def obtiene_rango_meses(year, month):
    """Retorna el primer y último día del mes dado."""
    primer_dia = datetime(year, month, 1)
    _, ultimo_dia = calendar.monthrange(year, month)
    ultimo_dia = datetime(year, month, ultimo_dia)
    return primer_dia, ultimo_dia

def ejecuta_consulta(conn, start_date, end_date):
    """Ejecuta la consulta SQL para el rango de fechas dado."""
    query = f"""
    WITH Festivos AS (
    SELECT FechaFestiva
        FROM (VALUES
            ('2023-01-01'),('2023-09-01'),('2023-20-03'),('2023-06-04'),('2023-07-04'),('2023-09-04'),('2023-01-05'),('2023-22-05'),('2023-12-06'),('2023-19-06'),('2023-03-07'),('2023-20-07'),('2023-07-08'),('2023-21-08'),('2023-16-10'),('2023-06-11'),('2023-13-11'),('2023-08-12'),('2023-25-12'),
            ('2024-01-01'),('2024-08-01'),('2024-25-03'),('2024-28-03'),('2024-29-03'),('2024-31-03'),('2024-01-05'),('2024-13-05'),('2024-03-06'),('2024-07-06'),('2024-01-07'),('2024-20-07'),('2024-07-08'),('2024-19-08'),('2024-14-10'),('2024-04-11'),('2024-11-11'),('2024-08-12'),('2024-25-12'),
            ('2025-01-01'),('2025-06-01'),('2025-24-03'),('2025-17-04'),('2025-18-04'),('2025-20-04'),('2025-01-05'),('2025-29-05'),('2025-19-06'),('2025-29-06'),('2025-30-06'),('2025-20-07'),('2025-07-08'),('2025-18-08'),('2025-13-10'),('2025-03-11'),('2025-17-11'),('2025-08-12'),('2025-25-12'),
            ('2026-01-01'),('2026-06-01'),('2026-23-03'),('2026-02-04'),('2026-03-04'),('2026-05-04'),('2026-01-05'),('2026-14-05'),('2026-04-06'),('2026-15-06'),('2026-29-06'),('2026-20-07'),('2026-07-08'),('2026-17-08'),('2026-12-10'),('2026-02-11'),('2026-16-11'),('2026-08-12'),('2026-25-12')
        ) AS F(FechaFestiva)
    ),
	Festivos_Fixed AS (
	SELECT CASE WHEN TRY_CAST(FechaFestiva As DATE) IS NULL THEN CONCAT(LEFT(FechaFestiva,4),'-',RIGHT(FechaFestiva,2),'-',RIGHT(LEFT(FechaFestiva,7),2)) ELSE CAST(FechaFestiva As DATE)	END FechaFestiva 
	FROM Festivos
	),
    Fechas AS (
        SELECT CAST('{start_date}' AS DATE) as Fecha
        UNION ALL
        SELECT DATEADD(DAY, 1, Fecha)
        FROM Fechas
        WHERE DATEADD(DAY, 1, Fecha) <= CAST('{end_date}' AS DATE)
    ),
    temp AS (
        SELECT DISTINCT 
            tpc.CentroCostos,
            tp.NombreProyecto,
            te.Documento,
            te.PrimerNombre,
            te.SegundoNombre,
            te.PrimerApellido,
            te.SegundoApellido,
            tcpr.Cargo,
            CASE WHEN ISNULL(tcpr.EsAdministrativo,0)= 0 THEN 'OPERATIVO' ELSE 'ADMINISTRATIVO' END Tipo,
            te.UsuarioRed,
            tep.FechaInicioContrato,
			CASE WHEN dtmFechaRetiro IS NULL THEN DATEADD( DAY,1,CAST(GETDATE() As DATE)) ELSE CAST(dtmFechaRetiro As DATE) END dtmFechaRetiro2,
            CASE 
				WHEN dtmFechaRetiro IS NULL 
					    AND (ISNULL(tc.LogActivo,0) = 0 AND ISNULL(tep.logActivo,0) = 0) 
					    AND (LAG(tep.FechaInicioContrato) OVER (PARTITION BY te.Documento ORDER BY CAST(tep.FechaInicioContrato As DATE) DESC)) IS NOT NULL 
                    THEN DATEADD(DAY,-1,(LAG(tep.FechaInicioContrato) OVER (PARTITION BY te.Documento ORDER BY CAST(tep.FechaInicioContrato As DATE) DESC)))
					
				WHEN dtmFechaRetiro IS NULL 
					    AND (ISNULL(tc.LogActivo,0) = 0 AND ISNULL(tep.logActivo,0) = 0) 
					    AND (LAG(tep.FechaInicioContrato) OVER (PARTITION BY te.Documento ORDER BY CAST(tep.FechaInicioContrato As DATE) DESC)) IS NULL 
				    THEN tep.FechaInicioContrato

				ELSE (CASE 
						WHEN dtmFechaRetiro IS NULL THEN CAST(GETDATE() As DATE) 
						ELSE CAST(dtmFechaRetiro As DATE) 
						END) 
				END dtmFechaRetiro,
            CASE WHEN dtmFechaRetiro IS NULL THEN 'ACTIVO' ELSE 'INACTIVO' END ESTADO,
            ISNULL(tc.LogActivo,0) ContratoLogActivo,
            ISNULL(tep.logActivo,0) EmpProyLogActivo
        FROM AGH_PRO.dbo.tblEmpleado te 
        INNER JOIN AGH_PRO.dbo.tblEmpleadoProy tep ON tep.IdEmpleado = te.IdEmpleado 
        INNER JOIN AGH_PRO.dbo.tblContrato tc ON tep.IdEmpleadoProySede = tc.IdEmpleadoProySede 
        INNER JOIN AGH_PRO.dbo.tblProyectoSede tps ON tps.IdProyectoSede = tep.IdProyectoSede 
        INNER JOIN AGH_PRO.dbo.tblProyecto tp ON tp.IdProyecto = tps.IdProyecto 
        INNER JOIN AGH_PRO.dbo.tblProyectoCCostos tpc ON tep.IdProyectoCCostos = tpc.IdProyectoCCostos 
        INNER JOIN AGH_PRO.dbo.tblCargoProyecto tcpr ON tep.IdCargoProyecto = tcpr.IdCargoProyecto 
        LEFT JOIN AGH_PRO.dbo.tblEmpleadoRetiro ter ON ter.IdEmpleado = te.IdEmpleado AND ter.IdEmpleadoProySede = tep.IdEmpleadoProySede
        WHERE ISNULL(tcpr.EsAdministrativo,0)= 0
			AND CAST(tep.FechaInicioContrato As DATE) != CASE WHEN dtmFechaRetiro IS NULL THEN DATEADD( DAY,1,CAST(GETDATE() As DATE)) ELSE CAST(dtmFechaRetiro As DATE) END
    ),
    ActivosPorFecha AS (
        SELECT DISTINCT Fecha,
            CAST(E.FechaInicioContrato AS DATE) FechaInicioContrato,
            CAST(E.dtmFechaRetiro AS DATE) FechaRetiro,
            CentroCostos,
            NombreProyecto,
            Documento,
            CONCAT(PrimerNombre,' ',PrimerApellido,' ',SegundoApellido) Nombre,
            E.Cargo,
            E.Tipo,
            E.ESTADO
        FROM Fechas F
        JOIN temp E 
			ON CAST(F.Fecha AS DATE) >= CAST(E.FechaInicioContrato AS DATE)
				AND CAST(F.Fecha AS DATE) <= CAST(E.dtmFechaRetiro AS DATE)
		LEFT JOIN Festivos_Fixed Fest
			ON Fest.FechaFestiva = F.Fecha
		WHERE CAST(Fest.FechaFestiva As DATE) IS NULL --> Excluir festivos
		 OR DATEPART(WEEKDAY,CAST(F.Fecha As DATE)) <> 7 --> Excluir domingos
    )

    SELECT 
        CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, Fecha), 0) As DATE) AS Mes,
        CASE
            WHEN LEN(CASE WHEN LEN(CentroCostos)>4 THEN LEFT(CentroCostos,4) ELSE CentroCostos END)=3 THEN CONCAT('0',(CASE WHEN LEN(CentroCostos)>4 THEN LEFT(CentroCostos,4) ELSE CentroCostos END))
            ELSE (CASE WHEN LEN(CentroCostos)>4 THEN LEFT(CentroCostos,4) ELSE CentroCostos END)
            END CentroCostos,
        COUNT(DISTINCT Documento) AS EmpleadosActivos
    FROM ActivosPorFecha
    GROUP BY DATEADD(MONTH, DATEDIFF(MONTH, 0, Fecha), 0), CentroCostos
    ORDER BY CentroCostos,DATEADD(MONTH, DATEDIFF(MONTH, 0, Fecha), 0)
	OPTION (MAXRECURSION 0);
    """
    return pd.read_sql(query, conn)

def main():
    start_time_total = datetime.now()
    hoy = datetime.now()
    anio_hoy = hoy.year
    mes_hoy = hoy.month
    
    all_data = pd.DataFrame()
    
    try:
        conn = pyodbc.connect(conn_str)
        
        for month in range(1, mes_hoy + 1, 2):
            start_time_iteration = datetime.now()
            start_date, _ = obtiene_rango_meses(anio_hoy, month)
            _, end_date = obtiene_rango_meses(anio_hoy, min(month + 1, mes_hoy))
            
            print(f"Procesando período: {start_date.strftime('%Y-%m-%d')} a {end_date.strftime('%Y-%m-%d')}")
            
            df = ejecuta_consulta(conn, start_date.strftime('%Y-%m-%d'), end_date.strftime('%Y-%m-%d'))
            all_data = pd.concat([all_data, df], ignore_index=True)

            end_time_iteration = datetime.now()
            duration_iteration = end_time_iteration - start_time_iteration
            print(f"Tiempo de ejecución para este período: {duration_iteration}")
        
        conn.close()
        
        # Eliminar duplicados si los hay
        all_data = all_data.drop_duplicates()
        
        # Guardar en CSV
        # csv_filename = f"C:\\Automatic\\AGH_Con\\empleados_activos_{anio_hoy}_{mes_hoy:02d}.csv"
        csv_filename = f"C:\\Automatic\\AGH_Con\\empleados_activos.csv"
        all_data.to_csv(csv_filename, index=False)
        nombre_archivo = csv_filename.split('\\')[-1]

        # CARGAR INFORME A SHAREPOINT
        upload_analytics_operativos_agh(nombre_archivo)

        # CONFIGURACION ENVIO DEL CORREO ELECTRONICO
        asunto = f'Consolidado AGH Cobertura Insp. Campo | {anio_hoy}_{mes_hoy:02d}'
        cuerpo = f'''El Consolidado AGH Cobertura Insp. Campo fue generado y cargado a la carpeta de SharePoint.<br>
        Dar clic <a href="https://inmelingenieria.sharepoint.com/sites/Analytics-0018-TICPrincipal/Documentos%20compartidos/Forms/AllItems.aspx?ga=1&id=%2Fsites%2FAnalytics%2D0018%2DTICPrincipal%2FDocumentos%20compartidos%2F0018%20%2D%20TIC%20Principal%2FdataInspCampo&viewid=38642e7b%2D5f73%2D462d%2D9f37%2Dfb9003811175">aqu&iacute</a> para ver el informe.
        '''
        destinatarios = ['jesus.ovalles@inmel.co', 'juan.ochoa@inmel.co']
        # Llama la funcion para el envio del informe por correo
        send_email(asunto,cuerpo,destinatarios)
        print('Consolidado exitoso')
        print(f"Datos guardados en {csv_filename}")

        end_time_total = datetime.now()
        duration_total = end_time_total - start_time_total
        print(f"Tiempo total de ejecución: {duration_total}")
        
    except pyodbc.Error as e:
        print(f"Error de conexión: {e}")
    except Exception as e:
        print(f"Error inesperado: {e}")
        import traceback
        print(traceback.format_exc())

if __name__ == "__main__":
    main()