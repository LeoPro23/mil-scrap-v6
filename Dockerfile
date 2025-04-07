# Usar la imagen oficial de Node.js como base
FROM node:22-slim

# Configuración de variables de entorno
ENV LANG=en_US.UTF-8 \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome-stable \
    DISPLAY=:99 \
    RESOLUTION=1366x768x24

# Instalar dependencias del sistema necesarias para Chrome y VNC
RUN apt-get update && apt-get install -y \
    fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-khmeros \
    fonts-kacst fonts-freefont-ttf \
    wget gnupg ca-certificates \
    dbus dbus-x11 \
    x11vnc xvfb \
    novnc websockify \
    supervisor \
    procps \
    xauth \
    libnss3 libgconf-2-4 \
    libasound2 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libxkbcommon0 libxcomposite1 \
    libxdamage1 libxfixes3 libxrandr2 libgbm1 libu2f-udev libvulkan1 \
    sed \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Instalar Google Chrome
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Crear directorios necesarios para X11
RUN mkdir -p /tmp/.X11-unix /tmp/.X0-lock && chmod 1777 /tmp/.X11-unix && chmod 1777 /tmp/

# Crear un archivo machine-id temporal para evitar el error de Chrome
RUN echo "1234567890abcdef1234567890abcdef" > /etc/machine-id

# Crear directorios necesarios para VNC
RUN mkdir -p /usr/share/novnc/utils/ || true

# Configurar noVNC
RUN ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html || true
RUN find / -name novnc_proxy -o -name launch.sh 2>/dev/null | xargs -I{} ln -sf {} /usr/share/novnc/utils/ || echo "noVNC utils no encontrados"

# Crear directorio de la aplicación
WORKDIR /app

# Copiar package.json y package-lock.json
COPY package*.json ./

# Instalar las dependencias
RUN npm install

# Instalar puppeteer-extra y plugins
RUN npm install puppeteer-extra puppeteer-extra-plugin-stealth axios jimp pixelmatch

# Copiar los archivos de la aplicación
COPY server.js ./
COPY scrap.js ./
COPY test.js ./
COPY captchaSolver.js ./

# Eliminar BOM (Byte Order Mark) de captchaSolver.js si existe
RUN sed -i '1s/^\xEF\xBB\xBF//' captchaSolver.js

# Configuración de supervisord para gestionar los procesos
COPY vnc_config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Crear directorio para los scripts de inicio
RUN mkdir -p /app/vnc_config
COPY vnc_config/start-vnc.sh /app/vnc_config/
RUN chmod +x /app/vnc_config/start-vnc.sh

# Exponer el puerto que usa Express y el puerto de VNC
EXPOSE 3001 6080

# Comando para iniciar supervisord que gestionará ambos servicios
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]