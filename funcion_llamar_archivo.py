from io import BytesIO
import requests
import pandas as pd
from shareplum import Office365
from datetime import datetime

# LEER ARCHIVOS DESDE SHAREPOINT (Simit)
def leer_archivo_sharepoint_simit(user,password):
    """ Leer un archivo de Sharepoint """
    config = {
        'sp_usuario': user,
        'sp_password': password,
        'sp_ruta_base': 'https://inmelingenieria.sharepoint.com',
        'sp_nombre_sitio': 'Analytics-0016',
        'sp_documentos_compartidos': 'Documentos%20compartidos%2F0016%20%2D%20Flota%2FSimit'
        }
    usuario = config['sp_usuario']
    password = config['sp_password']
    nombre_sitio = config['sp_nombre_sitio']
    ruta_base = config['sp_ruta_base']
    ruta_documentos = config['sp_documentos_compartidos']
    # Obtener cookie de autenticación
    authcookie = Office365(ruta_base, username=usuario, password=password).GetCookies()
    session = requests.Session()
    session.cookies = authcookie
    session.headers.update({'user-agent': 'python_bite/v1'})
    session.headers.update({'accept': 'application/json;odata=verbose'})
    # Obtener lista de archivos en la carpeta
    try:
        response = session.get(url=ruta_base + "/sites/" + nombre_sitio + "/_api/web/GetFolderByServerRelativeUrl('" + ruta_documentos + "')/Files")
        response.raise_for_status()
        archivos = response.json()
        enlace_completo = "Documentos%20compartidos%2F0016%20%2D%20Flota%2FSimit/"
        lista_ruta_archivos = [enlace_completo + info_archivos['Name'] for info_archivos in archivos['d']['results']]
        lista_fechas = []
        for l in lista_ruta_archivos:
            nombre = l.split('_')[-1].split('.')[0]
            nombre = datetime.strptime(nombre, '%Y-%m-%d')
            lista_fechas.append(nombre)
            # print(nombre)

        # Encontrar la fecha máxima utilizando la función max()
        fecha_maxima = str(max(lista_fechas)).split(' ')[0]
        print(fecha_maxima)
        # Leer y mostrar cada archivo
        for archivo in lista_ruta_archivos:
            if fecha_maxima in archivo:
                # Crear la ruta completa para leer archivo de Excel con pandas
                archivo_url = f"{ruta_base}/sites/{nombre_sitio}/{archivo}"
                archivo_response = session.get(archivo_url)
                archivo_response.raise_for_status()
                # Leer el contenido del archivo con pandas directamente desde la memoria
                contenido_archivo = BytesIO(archivo_response.content)
                df = pd.read_excel(contenido_archivo)
                print(df)
                return df          
    except Exception as e:
        print(f"Error al obtener la lista de archivos: {e}")
        return []

user = 'bi.admin@inmel.co'
password = 'tFC+Bqig.b47M'
leer_archivo_sharepoint_simit(user=user,password=password)