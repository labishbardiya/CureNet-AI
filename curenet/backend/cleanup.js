require('dotenv').config();
const mongoose = require('mongoose');

const Record = require('./src/models/recordModel');
const EmergencyShare = require('./src/models/EmergencyShare');
const AccessRequest = require('./src/models/AccessRequest');

async function cleanup() {
    try {
        const uri = process.env.MONGO_URI;
        if (!uri) {
            console.log("No MONGO_URI provided");
            return;
        }

        await mongoose.connect(uri);
        console.log("Connected to MongoDB.");

        // Delete all records where userId is not 'arjun'
        const recordsDeleted = await Record.deleteMany({ userId: { $ne: 'arjun' } });
        console.log(`Deleted ${recordsDeleted.deletedCount} non-Arjun records.`);

        // Delete all emergency shares where userId is not 'arjun'
        const sharesDeleted = await EmergencyShare.deleteMany({ userId: { $ne: 'arjun' } });
        console.log(`Deleted ${sharesDeleted.deletedCount} non-Arjun emergency shares.`);

        // Delete all access requests where patientUserId is not 'arjun'
        const accessDeleted = await AccessRequest.deleteMany({ patientUserId: { $ne: 'arjun' } });
        console.log(`Deleted ${accessDeleted.deletedCount} non-Arjun access requests.`);

        console.log("Database cleanup complete!");
    } catch (err) {
        console.error("Cleanup error:", err);
    } finally {
        await mongoose.disconnect();
    }
}

cleanup();
