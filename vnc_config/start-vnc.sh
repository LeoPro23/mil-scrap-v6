#!/bin/bash

# Establecer variables de entorno críticas para X11
export DISPLAY=:99
export XAUTHORITY=/tmp/.Xauthority
export LIBGL_ALWAYS_INDIRECT=1

# Configuraciones de sistema importantes para Chrome
echo "1234567890abcdef1234567890abcdef" > /etc/machine-id
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix
mkdir -p /dev/shm
chmod 1777 /dev/shm

# Crear directorios para X11
touch $XAUTHORITY
chmod 600 $XAUTHORITY
xauth generate :99 . trusted

echo "======================================"
echo "Iniciando servicios de VNC"
echo "Resolución: $RESOLUTION"
echo "Display: $DISPLAY"
echo "======================================"

# Iniciar Xvfb con configuración optimizada
echo "Iniciando Xvfb..."
Xvfb :99 -screen 0 $RESOLUTION -ac +extension GLX +render -noreset &
XVFB_PID=$!

# Asegurarse de que Xvfb está funcionando
sleep 3
if ! ps -p $XVFB_PID > /dev/null; then
    echo "ERROR: Xvfb no se pudo iniciar."
    exit 1
fi
echo "Xvfb iniciado correctamente en :99"

# Iniciar x11vnc con opciones más permisivas
echo "Iniciando servidor x11vnc..."
x11vnc -display :99 -rfbport 5900 -shared -forever -nopw -noxdamage -noxrecord -noxfixes -noxinerama -wait 5 -permitfiletransfer &
X11VNC_PID=$!

# Verificar que x11vnc está funcionando
sleep 3
if ! ps -p $X11VNC_PID > /dev/null; then
    echo "ERROR: x11vnc no se pudo iniciar."
    exit 1
fi
echo "x11vnc iniciado correctamente en puerto 5900"

# Establecer BASE_URL para el proxy reverso
BASE_URL=${BASE_URL:-"/"}
echo "Configurando noVNC con BASE_URL=$BASE_URL"

# Copiar archivos estáticos de noVNC a una ubicación accesible
echo "Configurando archivos estáticos de noVNC..."
mkdir -p /usr/share/novnc/static
cp -R /usr/share/novnc/* /usr/share/novnc/static/ 2>/dev/null || echo "No se pudieron copiar archivos estáticos"

# Iniciar noVNC con opciones adicionales para trabajar mejor con proxy
echo "Iniciando noVNC..."
if [ -f /usr/share/novnc/utils/novnc_proxy ]; then
    /usr/share/novnc/utils/novnc_proxy --vnc 127.0.0.1:5900 --listen 0.0.0.0:6080 --web /usr/share/novnc/static &
elif [ -f /usr/share/novnc/utils/launch.sh ]; then
    /usr/share/novnc/utils/launch.sh --vnc 127.0.0.1:5900 --listen 0.0.0.0:6080 --web /usr/share/novnc/static &
else
    websockify --web=/usr/share/novnc/static 0.0.0.0:6080 127.0.0.1:5900 &
fi
NOVNC_PID=$!

sleep 3
if ! ps -p $NOVNC_PID > /dev/null; then
    echo "ERROR: noVNC no se pudo iniciar."
    exit 1
fi
echo "noVNC iniciado correctamente en puerto 6080"

# Mostrar los procesos en ejecución
echo "======================================"
echo "Procesos VNC en ejecución:"
ps aux | grep -E 'Xvfb|x11vnc|novnc|websockify' | grep -v grep
echo "======================================"

echo "Puedes conectarte a VNC en: http://localhost:6080/"
echo "Mantén esta ventana abierta. El navegador Chrome aparecerá aquí."
echo "======================================"

# Mantener el script en ejecución
while true; do
    # Verificar que todos los servicios siguen en funcionamiento
    if ! ps -p $XVFB_PID > /dev/null || ! ps -p $X11VNC_PID > /dev/null || ! ps -p $NOVNC_PID > /dev/null; then
        echo "ERROR: Uno de los servicios VNC ha fallado. Reiniciando..."
        
        # Intentar matar procesos que puedan estar corriendo
        pkill -9 Xvfb || true
        pkill -9 x11vnc || true
        pkill -9 websockify || true
        pkill -9 novnc_proxy || true
        
        # Reiniciar Xvfb
        Xvfb :99 -screen 0 $RESOLUTION -ac +extension GLX +render -noreset &
        XVFB_PID=$!
        sleep 2
        
        # Reiniciar x11vnc
        x11vnc -display :99 -rfbport 5900 -shared -forever -nopw -noxdamage -noxrecord -noxfixes -noxinerama -wait 5 -permitfiletransfer &
        X11VNC_PID=$!
        sleep 2
        
        # Reiniciar noVNC con opciones para proxy
        if [ -f /usr/share/novnc/utils/novnc_proxy ]; then
            /usr/share/novnc/utils/novnc_proxy --vnc 127.0.0.1:5900 --listen 0.0.0.0:6080 --web /usr/share/novnc/static &
        elif [ -f /usr/share/novnc/utils/launch.sh ]; then
            /usr/share/novnc/utils/launch.sh --vnc 127.0.0.1:5900 --listen 0.0.0.0:6080 --web /usr/share/novnc/static &
        else
            websockify --web=/usr/share/novnc/static 0.0.0.0:6080 127.0.0.1:5900 &
        fi
        NOVNC_PID=$!
        sleep 2
        
        echo "Servicios VNC reiniciados"
    fi
    
    # Esperar 5 segundos antes de verificar nuevamente
    sleep 5
done