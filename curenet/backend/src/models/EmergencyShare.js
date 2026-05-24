const mongoose = require('mongoose');

const emergencyShareSchema = new mongoose.Schema({
    shareId: { type: String, required: true, unique: true },
    data: { type: Object, required: true },
    createdAt: { type: Date, default: Date.now, expires: 3600 } // Auto-delete after 1 hour
});

module.exports = mongoose.model('EmergencyShare', emergencyShareSchema);
