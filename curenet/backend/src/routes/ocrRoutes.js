const express = require('express');
const router = express.Router();
const upload = require('../utils/fileHandler');
const ocrController = require('../controllers/ocrController');

// Accept any file upload to avoid strict field-name "Unexpected field" errors during debugging
router.post('/scan', upload.any(), ocrController.initiateScan);

// Job Status Fetching
router.get('/status/:jobId', ocrController.getScanStatus);

module.exports = router;
