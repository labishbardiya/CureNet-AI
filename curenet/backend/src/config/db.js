const mongoose = require('mongoose');

const connectDB = async () => {
    try {
        const uri = process.env.MONGO_URI;

        if (!uri) {
            console.log(`[Database] MONGO_URI missing. Falling back to In-Memory mock DB.`);
            return;
        }

        await mongoose.connect(uri);
        console.log(`[Database] MongoDB Connected to production cluster.`);
    } catch (err) {
        console.error(`[Database Error] ${err.message}`);
        console.log(`[Database] Connection failed. Falling back to In-Memory mock DB.`);
    }
};

module.exports = connectDB;
