const mongoose = require('mongoose');

const vitalSchema = new mongoose.Schema({
    userId: { type: String, required: true },
    type: { type: String, required: true }, // e.g., 'bp', 'pulse', 'temperature', 'weight'
    value: { type: mongoose.Schema.Types.Mixed, required: true },
    date: { type: Date, required: true },
    source: { type: String, default: 'ocr' }
}, {
    timeseries: {
        timeField: 'date',
        metaField: 'userId',
        granularity: 'hours'
    }
});

module.exports = mongoose.model('Vital', vitalSchema);
