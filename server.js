// server.js

const express = require('express');
const scrapeMilanuncios = require('./scrap');
const axios = require('axios');

const app = express();
const port = process.env.PORT || 3000;

app.get('/scrape', async (req, res) => {
  try {
    // Extrae los parámetros de búsqueda desde la query string
    const searchParams = req.query;
    console.log('Parámetros recibidos gaa:', searchParams);

    // Llama a la función de scraping con los parámetros recibidos
    const data = await scrapeMilanuncios(searchParams);
    const n8nWebhookUrl = 'https://n8n.sitemaster.lat/webhook/leotest'; // Reemplaza con tu URL real
    await axios.post(n8nWebhookUrl, data, {
      headers: {
        'Content-Type': 'application/json'
      }
    });
    console.log('Datos enviados exitosamente al flujo de n8n');

    res.json({ success: true, data });
  } catch (error) {
    console.error('Error en scraping:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

app.listen(port, () => {
  console.log(`Servidor corriendo en el puerta ${port}`);
});
