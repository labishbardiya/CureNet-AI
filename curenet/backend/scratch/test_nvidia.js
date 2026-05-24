const { generateEmbedding } = require('../src/services/embeddingService');
require('dotenv').config();

async function testNvidia() {
    console.log('--- Testing NVIDIA NIM Embedding Integration ---');
    const testText = "Patient has a history of severe hypertension and is currently taking Telmisartan 40mg.";
    
    try {
        console.log('Generating embedding for:', testText);
        const vector = await generateEmbedding(testText);
        
        console.log('Vector Length:', vector.length);
        console.log('First 5 values:', vector.slice(0, 5));
        
        if (vector.length === 1024) {
            console.log('✅ SUCCESS: 1024-dim vector generated successfully (NVIDIA standard).');
            if (process.env.NVIDIA_EMBEDDING_KEY && !vector.every(v => v === 0)) {
                console.log('✅ AUTH VERIFIED: Key is active and returning data.');
            } else {
                 console.log('⚠️ NOTE: Check if NVIDIA_EMBEDDING_KEY is valid in .env');
            }
        } else {
            console.log('❌ FAILURE: Incorrect vector dimensions.');
        }
    } catch (err) {
        console.error('❌ ERROR:', err.message);
    }
}

testNvidia();
