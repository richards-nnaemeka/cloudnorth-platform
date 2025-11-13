const express = require('express');
const path = require('path');
const app = express();

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// API route to proxy backend requests
app.get('/api/products', async (req, res) => {
    try {
        const backendResponse = await fetch('http://backend:5000/api/products');
        const products = await backendResponse.json();
        res.json(products);
    } catch (error) {
        res.status(500).json({ error: 'Backend service unavailable' });
    }
});

app.get('/api/health', (req, res) => {
    res.json({ status: 'healthy', service: 'frontend' });
});

app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(Frontend server running on port );
});
