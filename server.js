// server.js

const express = require('express');
const scrapeMilanuncios = require('./scrap');
const axios = require('axios');

const app = express();
const port = process.env.PORT || 3000;

// Middleware para logging de peticiones
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
  next();
});

// Endpoint principal de scraping
app.get('/scrape', async (req, res) => {
  try {
    // Extrae los parámetros de búsqueda desde la query string
    const searchParams = req.query;
    console.log('Parámetros recibidos:', searchParams);

    // Llamar a la función de scraping con los parámetros recibidos
    const data = await scrapeMilanuncios(searchParams);
    
    // Enviar datos a webhook si está configurado
    try {
      const n8nWebhookUrl = 'https://n8n.sitemaster.lat/webhook/leotest'; // Reemplaza con tu URL real
      await axios.post(n8nWebhookUrl, data, {
        headers: {
          'Content-Type': 'application/json'
        }
      });
      console.log('Datos enviados exitosamente al flujo de n8n');
    } catch (webhookError) {
      console.error('Error al enviar datos al webhook:', webhookError.message);
      // No fallamos toda la petición si solo falla el webhook
    }

    res.json({ success: true, data });
  } catch (error) {
    console.error('Error en scraping:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Endpoint para verificar el estado del servidor
app.get('/status', (req, res) => {
  res.json({ 
    status: 'OK',
    time: new Date().toISOString(),
    uptime: process.uptime(),
    version: '1.0.0'
  });
});

// Iniciar el servidor
const server = app.listen(port, () => {
  console.log(`Servidor corriendo en el puerto ${port}`);
  console.log(`Para scraping: http://localhost:${port}/scrape?s=hyundai+negro`);
  console.log(`Para visualización VNC: http://localhost:6080/vnc.html`);
});

// Manejar la salida limpia del servidor
process.on('SIGINT', () => {
  console.log('\nCerrando servidor...');
  server.close(() => {
    console.log('Servidor HTTP cerrado');
    process.exit(0);
  });
});
