const fs = require('fs');
const Record = require('../models/recordModel');
const { generateId } = require('../utils/idGenerator');

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
