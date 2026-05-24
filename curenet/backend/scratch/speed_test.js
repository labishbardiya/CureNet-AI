const { extractWithVisionLlm } = require('../src/services/ocr/visionLlmService');
const path = require('path');

const testImage = path.join(__dirname, '../test_images/image.png');

async function runTest() {
    console.log('🚀 Starting speed test for Vision LLM extraction...');
    const start = Date.now();
    
    try {
        const result = await extractWithVisionLlm(testImage);
        const end = Date.now();
        const duration = (end - start) / 1000;
        
        console.log('\n✅ Extraction Successful!');
        console.log(`⏱️ Total Time: ${duration.toFixed(2)} seconds`);
        console.log('-----------------------------------');
        console.log('Full Result:');
        console.log(JSON.stringify(result, null, 2));
        console.log('-----------------------------------');
        
    } catch (err) {
        console.error('❌ Test failed:', err.message);
    }
}

runTest();
