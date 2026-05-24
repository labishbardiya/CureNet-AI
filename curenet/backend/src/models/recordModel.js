const mongoose = require('mongoose');

const RecordSchema = new mongoose.Schema({
    jobId: {
        type: String,
        required: true,
        index: true
    },
    userId: {
        type: String,
        default: 'arjun',
        index: true
    },
    status: {
        type: String,
        enum: ['pending', 'processing', 'completed', 'failed'],
        default: 'pending'
    },
    recordId: {
        type: String
    },
    raw_text: {
        type: String
    },
    clean_text: {
        type: String
    },
    confidence_score: {
        type: Number
    },
    abdmContext: {
        isReadyForLink: { type: Boolean, default: false },
        hiType: { type: String, default: 'DiagnosticReport' }, 
        displayString: { type: String }
    },
    warnings: [{
        type: String
    }],
    filePath: {
        type: String
    },
    fhirBundle: {
        type: Object
    },
    uiData: {
        type: Object
    },
    clinical_atoms: [{
        type: { type: String }, // 'medication' | 'observation' | 'condition'
        name: String,
        value: String,
        unit: String,
        date: String,
        metadata: Object
    }],
    vector_embedding: {
        type: [Number], // Array of floats for Atlas Vector Search
        index: true
    }
}, { timestamps: true });

module.exports = mongoose.model('Record', RecordSchema);
