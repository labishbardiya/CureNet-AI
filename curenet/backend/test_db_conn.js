require('dotenv').config();
const mongoose = require('mongoose');

async function testConnection() {
    try {
        const uri = process.env.MONGO_URI;
        console.log('[Test] Attempting to connect to:', uri.split('@')[1]); // Log only the host for security
        await mongoose.connect(uri);
        console.log('[Test] ✅ MongoDB Connection Successful!');
        process.exit(0);
    } catch (err) {
        console.error('[Test] ❌ MongoDB Connection Failed:', err.message);
        process.exit(1);
    }
}

testConnection();
