const mongoose = require('mongoose');

const accessRequestSchema = new mongoose.Schema({
    requestId: { type: String, required: true, unique: true, index: true },
    shareId: { type: String, required: true },
    patientUserId: { type: String, default: 'arjun', index: true },
    doctorInfo: {
        name: { type: String, default: 'Doctor' },
        device: { type: String, default: 'Unknown Device' }
    },
    status: {
        type: String,
        enum: ['pending', 'approved', 'denied', 'revoked'],
        default: 'pending'
    },
    respondedAt: { type: Date },
    expiresAt: { type: Date },
    createdAt: { type: Date, default: Date.now, expires: 7200 } // Auto-delete after 2 hours
});

module.exports = mongoose.model('AccessRequest', accessRequestSchema);
