# device_radar

Una aplicación para monitorear dispositivos en la red.

## Funcionalidades de la aplicación:

Añadir dispositivos manualmente:

Ingresa un nombre y dirección IP
Presiona "Añadir"


Escanear red:

Presiona "Escanear Red" para detectar dispositivos en la red local
Selecciona un dispositivo encontrado para añadirlo


Monitoreo:

El monitoreo comienza automáticamente al añadir dispositivos
La app comprueba cada 10 segundos si los dispositivos están encendidos
Recibirás una notificación con sonido cuando un dispositivo cambie de estado


Visualización:

Verde: Dispositivo encendido
Rojo: Dispositivo apagado


Controles:

Botón Play/Stop en la barra superior para iniciar/detener el monitoreo



Esta aplicación utiliza ping para comprobar si los dispositivos están respondiendo en la red y guarda la configuración localmente para que persista entre sesiones.
