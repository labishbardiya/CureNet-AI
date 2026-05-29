require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const connectDB = require('./config/db');

// Explicitly require the worker service to boot up the internal polling queue
require('./services/workerService'); 

const ocrRoutes = require('./routes/ocrRoutes');
const recordRoutes = require('./routes/recordRoutes');
const emergencyRoutes = require('./routes/emergencyRoutes');
const accessRoutes = require('./routes/accessRoutes');

const app = express();

// Middleware
app.use((req, res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
    next();
});
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Doctor's Portal — Static Files
app.use('/portal', express.static(path.join(__dirname, '..', 'public')));

// Database initialization
connectDB();

// API Routing
app.use('/api/ocr', ocrRoutes);
app.use('/api/records', recordRoutes);
app.use('/api/emergency', emergencyRoutes);
app.use('/api/access', accessRoutes);

app.get('/', (req, res) => {
    res.send({ status: 'ok', msg: 'HIP ABDM OCR Service is Active.' });
});

// Boot handling
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`[Server] ABDM HIP Server running on 0.0.0.0:${PORT}`);
    console.log(`[Portal] Doctor's Portal available at http://localhost:${PORT}/portal`);
});

