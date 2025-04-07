#!/usr/bin/bash
set -x # Enable command tracing

# Log environment variables for debugging
/usr/bin/env > /tmp/vnc_env.log

# Establecer variables de entorno críticas para X11
export DISPLAY=:99
export XAUTHORITY=/tmp/.Xauthority
export LIBGL_ALWAYS_INDIRECT=1

# Ensure RESOLUTION is set properly with a default value
export RESOLUTION=${RESOLUTION:-"1366x768x24"}

# Configuraciones de sistema importantes para Chrome
/bin/echo "1234567890abcdef1234567890abcdef" > /etc/machine-id
/bin/mkdir -p /tmp/.X11-unix
/bin/chmod 1777 /tmp/.X11-unix
/bin/mkdir -p /dev/shm
/bin/chmod 1777 /dev/shm

# Crear directorios para X11
/usr/bin/touch $XAUTHORITY
/bin/chmod 600 $XAUTHORITY
/usr/bin/xauth generate :99 . trusted

/bin/echo "======================================"
/bin/echo "Iniciando servicios de VNC"
/bin/echo "Resolución: $RESOLUTION"
/bin/echo "Display: $DISPLAY"
/bin/echo "======================================"

# Iniciar Xvfb con configuración optimizada y logueo
/bin/echo "Iniciando Xvfb..."
/usr/bin/Xvfb :99 -screen 0 ${RESOLUTION} -ac +extension GLX +render -noreset > /tmp/xvfb.log 2>&1 &
XVFB_PID=$!

# Asegurarse de que Xvfb está funcionando
/bin/sleep 3
if ! /bin/ps -p $XVFB_PID > /dev/null; then
    /bin/echo "ERROR: Xvfb no se pudo iniciar. Ver /tmp/xvfb.log"
    /bin/cat /tmp/xvfb.log # Mostrar log si falla
    exit 1
fi
/bin/echo "Xvfb iniciado correctamente en :99"

# Iniciar x11vnc con opciones más permisivas y logueo
/bin/echo "Iniciando servidor x11vnc..."
/usr/bin/x11vnc -display :99 -rfbport 5900 -shared -forever -nopw -noxdamage -noxrecord -noxfixes -noxinerama -wait 5 -permitfiletransfer > /tmp/x11vnc.log 2>&1 &
X11VNC_PID=$!

# Verificar que x11vnc está funcionando
/bin/sleep 3
if ! /bin/ps -p $X11VNC_PID > /dev/null; then
    /bin/echo "ERROR: x11vnc no se pudo iniciar. Ver /tmp/x11vnc.log"
    /bin/cat /tmp/x11vnc.log # Mostrar log si falla
    exit 1
fi
/bin/echo "x11vnc iniciado correctamente en puerto 5900"

# Establecer BASE_URL para el proxy reverso y NOVNC_PORT
BASE_URL=${BASE_URL:-"/"}
NOVNC_PORT=${NOVNC_PORT:-"6080"}
/bin/echo "Configurando noVNC con BASE_URL=$BASE_URL en puerto $NOVNC_PORT"

# Copiar archivos estáticos de noVNC a una ubicación accesible
/bin/echo "Configurando archivos estáticos de noVNC..."
/bin/mkdir -p /usr/share/novnc/static
/bin/cp -R /usr/share/novnc/* /usr/share/novnc/static/ 2>/dev/null || /bin/echo "No se pudieron copiar archivos estáticos"

# Iniciar noVNC con opciones adicionales para trabajar mejor con proxy y logueo
/bin/echo "Iniciando noVNC..."
if [ -f /usr/share/novnc/utils/novnc_proxy ]; then
    /usr/share/novnc/utils/novnc_proxy --vnc 127.0.0.1:5900 --listen 0.0.0.0:${NOVNC_PORT} --web /usr/share/novnc/static > /tmp/novnc.log 2>&1 &
elif [ -f /usr/share/novnc/utils/launch.sh ]; then
    /usr/share/novnc/utils/launch.sh --vnc 127.0.0.1:5900 --listen 0.0.0.0:${NOVNC_PORT} --web /usr/share/novnc/static > /tmp/novnc.log 2>&1 &
else
    /usr/bin/websockify --web=/usr/share/novnc/static 0.0.0.0:${NOVNC_PORT} 127.0.0.1:5900 > /tmp/novnc.log 2>&1 &
fi
NOVNC_PID=$!

/bin/sleep 3
if ! /bin/ps -p $NOVNC_PID > /dev/null; then
    /bin/echo "ERROR: noVNC no se pudo iniciar. Ver /tmp/novnc.log"
    /bin/cat /tmp/novnc.log # Mostrar log si falla
    exit 1
fi
/bin/echo "noVNC iniciado correctamente en puerto ${NOVNC_PORT}"

# Mostrar los procesos en ejecución
/bin/echo "======================================"
/bin/echo "Procesos VNC en ejecución:"
/bin/ps aux | /bin/grep -E 'Xvfb|x11vnc|novnc|websockify' | /bin/grep -v grep
/bin/echo "======================================"

/bin/echo "Puedes conectarte a VNC en: http://localhost:${NOVNC_PORT}/"
/bin/echo "Mantén esta ventana abierta. El navegador Chrome aparecerá aquí."
/bin/echo "======================================"

# Mantener el script en ejecución
while true; do
    # Verificar que todos los servicios siguen en funcionamiento
    if ! /bin/ps -p $XVFB_PID > /dev/null || ! /bin/ps -p $X11VNC_PID > /dev/null || ! /bin/ps -p $NOVNC_PID > /dev/null; then
        /bin/echo "ERROR: Uno de los servicios VNC ha fallado. Revisando logs..."
        /bin/echo "--- Xvfb Log (/tmp/xvfb.log) ---"
        /usr/bin/tail -n 20 /tmp/xvfb.log || /bin/echo "No log found"
        /bin/echo "--- x11vnc Log (/tmp/x11vnc.log) ---"
        /usr/bin/tail -n 20 /tmp/x11vnc.log || /bin/echo "No log found"
        /bin/echo "--- noVNC Log (/tmp/novnc.log) ---"
        /usr/bin/tail -n 20 /tmp/novnc.log || /bin/echo "No log found"
        /bin/echo "Reiniciando servicios VNC..."

        # Intentar matar procesos que puedan estar corriendo
        /usr/bin/pkill -9 Xvfb || true
        /usr/bin/pkill -9 x11vnc || true
        /usr/bin/pkill -9 websockify || true
        /usr/bin/pkill -9 novnc_proxy || true

        # Reiniciar Xvfb
        /usr/bin/Xvfb :99 -screen 0 ${RESOLUTION} -ac +extension GLX +render -noreset > /tmp/xvfb.log 2>&1 &
        XVFB_PID=$!
        /bin/sleep 2

        # Reiniciar x11vnc
        /usr/bin/x11vnc -display :99 -rfbport 5900 -shared -forever -nopw -noxdamage -noxrecord -noxfixes -noxinerama -wait 5 -permitfiletransfer > /tmp/x11vnc.log 2>&1 &
        X11VNC_PID=$!
        /bin/sleep 2

        # Reiniciar noVNC con opciones para proxy
        if [ -f /usr/share/novnc/utils/novnc_proxy ]; then
            /usr/share/novnc/utils/novnc_proxy --vnc 127.0.0.1:5900 --listen 0.0.0.0:${NOVNC_PORT} --web /usr/share/novnc/static > /tmp/novnc.log 2>&1 &
        elif [ -f /usr/share/novnc/utils/launch.sh ]; then
            /usr/share/novnc/utils/launch.sh --vnc 127.0.0.1:5900 --listen 0.0.0.0:${NOVNC_PORT} --web /usr/share/novnc/static > /tmp/novnc.log 2>&1 &
        else
            /usr/bin/websockify --web=/usr/share/novnc/static 0.0.0.0:${NOVNC_PORT} 127.0.0.1:5900 > /tmp/novnc.log 2>&1 &
        fi
        NOVNC_PID=$!
        /bin/sleep 2

        /bin/echo "Servicios VNC reiniciados"
    fi

    # Esperar 5 segundos antes de verificar nuevamente
    /bin/sleep 5
done