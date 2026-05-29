const fs = require('fs');
const Record = require('../models/recordModel');
const { generateId } = require('../utils/idGenerator');
const { eventQueue } = require('../services/workerService');

/**
 * Initiates the asynchronous OCR process.
 * Stores the file temporarily and immediately pushes a Pending job response to the flutter frontend.
 */
exports.initiateScan = async (req, res) => {
    try {
        const file = req.file || (req.files && req.files[0]);
        if (!file) {
            return res.status(400).json({ error: 'Please upload an image or PDF file.' });
        }

        const jobId = generateId();
        const userId = req.body.userId || req.query.userId || 'arjun';

        // Register tracking in memory/mock DB
        const newJob = new Record({
            jobId,
            userId,
            status: 'pending',
            filePath: file.path
        });

        await newJob.save();

        // Drop the job onto the Event Queue (simulating BullMQ)
        eventQueue.emit('newJob', jobId);

        res.status(202).json({
            status: 'success',
            message: 'Scan job submitted to background worker.',
            data: {
                jobId,
                userId,
                status: 'pending'
            }
        });
    } catch (err) {
        // Cleanup file if DB save fails
        const file = req.file || (req.files && req.files[0]);
        if (file && fs.existsSync(file.path)) {
            fs.unlinkSync(file.path);
        }
        res.status(500).json({ error: 'Internal Server Error: ' + err.message });
    }
};

/**
 * Allows the frontend (or ABDM modules) to poll for the OCR outcome using the Job ID.
 *
 * Returns the unified output format:
 *   - fhir_bundle:  ABDM-compliant FHIR R4 Document Bundle
 *   - ui_data:      Flat, UI-optimized structured output
 *   - abdmContext:   Quick-access metadata
 */
exports.getScanStatus = async (req, res) => {
    try {
        const { jobId } = req.params;

        const record = await Record.findOne({ jobId });

        if (!record) {
            return res.status(404).json({ error: 'Job ID not found.' });
        }

        if (record.status !== 'completed') {
            return res.status(200).json({
                status: 'success',
                data: {
                    jobId: record.jobId,
                    state: record.status,
                    error: record.error
                }
            });
        }

        // Job completed — return unified output
        res.status(200).json({
            status: 'success',
            data: {
                jobId: record.jobId,
                status: record.status,
                confidence_score: record.confidence_score,
                abdmContext: record.abdmContext,
                fhir_bundle: record.fhirBundle,
                ui_data: record.uiData
            }
        });
    } catch (err) {
        res.status(500).json({ error: 'Internal Server Error: ' + err.message });
    }
};

/**
 * Server-Sent Events (SSE) Endpoint for real-time push notification.
 * The Flutter client connects to this stream and waits for the job to complete.
 * This guarantees zero polling latency.
 */
exports.streamScanStatus = (req, res) => {
    const { jobId } = req.params;

    // Set headers for SSE
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    // Send an initial connected ping
    res.write(`data: {"status":"connected","jobId":"${jobId}"}\n\n`);

    const onComplete = (record) => {
        if (record.jobId === jobId) {
            res.write(`data: ${JSON.stringify({
                status: 'success',
                data: {
                    jobId: record.jobId,
                    status: record.status,
                    confidence_score: record.confidence_score,
                    abdmContext: record.abdmContext,
                    fhir_bundle: record.fhirBundle,
                    ui_data: record.uiData
                }
            })}\n\n`);
            cleanup();
        }
    };

    const onFailed = (record) => {
        if (record.jobId === jobId) {
            res.write(`data: ${JSON.stringify({
                status: 'error',
                data: { jobId: record.jobId, state: 'failed', error: record.error }
            })}\n\n`);
            cleanup();
        }
    };

    eventQueue.on('jobCompleted', onComplete);
    eventQueue.on('jobFailed', onFailed);

    const cleanup = () => {
        eventQueue.off('jobCompleted', onComplete);
        eventQueue.off('jobFailed', onFailed);
        res.end();
    };

    req.on('close', cleanup);
};
