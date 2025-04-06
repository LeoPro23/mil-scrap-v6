# Usar la imagen oficial de Node.js como base
FROM node:22-slim

# Configuración de variables de entorno
ENV LANG=en_US.UTF-8 \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/google-chrome-stable

# Instalar dependencias del sistema necesarias para Chrome
RUN apt-get update && apt-get install -y \
    fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-khmeros \
    fonts-kacst fonts-freefont-ttf \
    wget gnupg ca-certificates \
    dbus dbus-x11 \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Instalar Google Chrome
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Crear directorio de la aplicación
WORKDIR /app

# Copiar package.json y package-lock.json
COPY package*.json ./

# Instalar las dependencias
RUN npm install

# Instalar puppeteer-extra y plugins
RUN npm install puppeteer-extra puppeteer-extra-plugin-stealth axios

# Copiar los archivos de la aplicación
COPY server.js ./
COPY scrap.js ./

# Configuración de red para Puppeteer
ENV DBUS_SESSION_BUS_ADDRESS=/dev/null

# Exponer el puerto que usa Express
EXPOSE 3000

# Comando para iniciar la aplicación
CMD ["node", "server.js"]