const express = require('express');
const router = express.Router();
const Record = require('../models/recordModel');
const { generateEmbedding } = require('../services/embeddingService');

/**
 * @route GET /api/records/all
 * @desc Fetch all clinical records. Optionally filter by userId via query param.
 */
router.get('/all', async (req, res) => {
    try {
        const filter = { status: 'completed' };
        if (req.query.userId) {
            filter.userId = req.query.userId;
        }
        const records = await Record.find(filter).sort({ createdAt: -1 });
        res.status(200).json({
            status: 'success',
            results: records.length,
            data: records
        });
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch records: ' + err.message });
    }
});

/**
 * @route POST /api/records/search/semantic
 * @desc Perform semantic search across clinical records using vector embeddings.
 */
router.post('/search/semantic', async (req, res) => {
    const { query } = req.body;
    try {
        const queryVector = await generateEmbedding(query);
        
        // ATLAS VECTOR SEARCH (Aggregations)
        const results = await Record.aggregate([
            {
                "$vectorSearch": {
                    "index": "vector_index",
                    "path": "vector_embedding",
                    "queryVector": queryVector,
                    "numCandidates": 100,
                    "limit": 10
                }
            },
            {
                "$project": {
                    "uiData": 1,
                    "abdmContext": 1,
                    "score": { "$meta": "vectorSearchScore" }
                }
            }
        ]);

        res.status(200).json({
            status: 'success',
            results: results.length,
            data: results
        });
    } catch (err) {
        const fallbackResults = await Record.find({
            $or: [
                { "uiData.summary.diagnosis": { $regex: query, $options: 'i' } },
                { "clean_text": { $regex: query, $options: 'i' } }
            ]
        }).limit(10);
        
        res.status(200).json({
            status: 'success',
            results: fallbackResults.length,
            data: fallbackResults,
            isFallback: true
        });
    }
});

/**
 * @route GET /api/records/atoms
 * @desc Fetch all clinical atoms for longitudinal AI reasoning. Optionally filter by userId.
 */
router.get('/atoms', async (req, res) => {
    try {
        const filter = { status: 'completed' };
        if (req.query.userId) {
            filter.userId = req.query.userId;
        }
        const records = await Record.find(filter, 'clinical_atoms');
        let allAtoms = [];
        records.forEach(r => {
            if (r.clinical_atoms && r.clinical_atoms.length > 0) {
                allAtoms = allAtoms.concat(r.clinical_atoms);
            }
        });
        res.status(200).json({
            status: 'success',
            results: allAtoms.length,
            data: allAtoms
        });
    } catch (err) {
        res.status(500).json({ error: 'Failed to fetch atoms: ' + err.message });
    }
});

/**
 * @route DELETE /api/records/:id
 * @desc Permanently delete a record and its vector embeddings.
 */
router.delete('/:id', async (req, res) => {
    try {
        const result = await Record.findByIdAndDelete(req.params.id);
        if (!result) {
            return res.status(404).json({ error: 'Record not found' });
        }
        res.status(200).json({ status: 'success', message: 'Record deleted from cloud' });
    } catch (err) {
        res.status(500).json({ error: 'Failed to delete record: ' + err.message });
    }
});

module.exports = router;
