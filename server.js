// server.js - Servidor mejorado con manejo de captchas y reintentos
const express = require('express');
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const scrapeMilanuncios = require('./scrap');

// Crear directorio para logs si no existe
const logsDir = path.join(__dirname, 'logs');
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir, { recursive: true });
}

// Función para logging con timestamp
function logWithTimestamp(message, isError = false) {
  const timestamp = new Date().toISOString();
  const logMessage = `[${timestamp}] ${message}`;
  
  // Mostrar en consola
  if (isError) {
    console.error(logMessage);
  } else {
    console.log(logMessage);
  }
  
  // Escribir a archivo de log
  fs.appendFileSync(
    path.join(logsDir, isError ? 'error.log' : 'server.log'), 
    logMessage + '\n', 
    { encoding: 'utf8' }
  );
}

const app = express();
// Asegurar que usamos el puerto de la variable de entorno, que en docker-compose es 3000
const port = process.env.PORT || 3000;

// Middleware para registrar todas las peticiones
app.use((req, res, next) => {
  logWithTimestamp(`${req.method} ${req.url}`);
  next();
});

app.get('/scrape', async (req, res) => {
  try {
    // Obtener los parámetros de búsqueda
    const searchParams = req.query;
    logWithTimestamp(`Parámetros recibidos: ${JSON.stringify(searchParams)}`);
    
    // Registrar desde dónde viene la petición
    const clientIP = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
    const userAgent = req.headers['user-agent'];
    logWithTimestamp(`Petición desde IP: ${clientIP}, User-Agent: ${userAgent}`);
    
    // Validar parámetros mínimos
    if (!searchParams.s) {
      logWithTimestamp('Petición rechazada: falta el parámetro de búsqueda "s"', true);
      return res.status(400).json({ 
        success: false, 
        error: 'Se requiere el parámetro de búsqueda "s"' 
      });
    }

    // Llamar a la función de scraping con los parámetros recibidos
    logWithTimestamp('Iniciando proceso de scraping...');
    const startTime = Date.now();
    
    try {
      const data = await scrapeMilanuncios(searchParams);
      const endTime = Date.now();
      const duration = (endTime - startTime) / 1000;
      
      logWithTimestamp(`Scraping completado en ${duration.toFixed(2)} segundos. Obtenidos ${Array.isArray(data) ? data.length : 0} resultados.`);
      
      // Si está configurada una URL de webhook, enviar los datos
      const n8nWebhookUrl = process.env.N8N_WEBHOOK_URL;
      if (n8nWebhookUrl) {
        try {
          logWithTimestamp(`Enviando datos a webhook: ${n8nWebhookUrl}`);
          // Modificado: Enviamos los datos dentro de un objeto con la propiedad 'body'
          await axios.post(n8nWebhookUrl, { body: data }, {
            headers: { 'Content-Type': 'application/json' }
          });
          logWithTimestamp('Datos enviados exitosamente al webhook');
        } catch (webhookError) {
          logWithTimestamp(`Error al enviar datos al webhook: ${webhookError.message}`, true);
          // No fallamos la petición principal si falla el webhook
        }
      }
      
      // Responder al cliente
      res.json({ success: true, data });
      
    } catch (scrapingError) {
      logWithTimestamp(`Error en el proceso de scraping: ${scrapingError.message}`, true);
      
      // Tomar decisión según el tipo de error
      if (scrapingError.message.includes('captcha') || 
          scrapingError.message.includes('verification') ||
          scrapingError.message.includes('blocked')) {
        return res.status(429).json({
          success: false,
          error: 'Detectada verificación de seguridad o captcha que no se pudo resolver automáticamente',
          message: scrapingError.message
        });
      }
      
      return res.status(500).json({
        success: false,
        error: 'Error durante el proceso de scraping',
        message: scrapingError.message
      });
    }
    
  } catch (error) {
    logWithTimestamp(`Error general en la petición: ${error.message}`, true);
    res.status(500).json({ 
      success: false, 
      error: 'Error interno del servidor',
      message: error.message 
    });
  }
});

// Endpoint para verificar estado del servidor
app.get('/health', (req, res) => {
  res.json({
    status: 'UP',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Iniciar el servidor
app.listen(port, () => {
  logWithTimestamp(`Servidor corriendo en el puerto ${port}`);
});
