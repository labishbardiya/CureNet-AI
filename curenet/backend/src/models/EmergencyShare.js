const mongoose = require('mongoose');

const emergencyShareSchema = new mongoose.Schema({
    shareId: { type: String, required: true, unique: true },
    userId: { type: String, required: false }, // Patient's identity
    data: { type: Object, required: true },
    createdAt: { type: Date, default: Date.now, expires: 3600 } // Auto-delete after 1 hour
});

module.exports = mongoose.model('EmergencyShare', emergencyShareSchema);
