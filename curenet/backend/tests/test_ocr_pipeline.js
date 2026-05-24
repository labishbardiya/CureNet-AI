const path = require('path');
const { runHybridOcr } = require('../src/services/ocr/pythonBridge');
const { parsePrescriptionText } = require('../src/services/ocr/parserService');

async function testPipeline() {
    const imagePath = path.resolve(__dirname, '../../prescription.webp');
    console.log(`[Test] Starting end-to-end test for: ${imagePath}`);

    try {
        // 1. OCR Stage
        console.log('\n--- STAGE 1: HYBRID OCR ---');
        const ocrResult = await runHybridOcr(imagePath);
        console.log('OCR Output (Clean Text Snippet):', ocrResult.final_raw_text.substring(0, 200), '...');

        // 2. Parsing Stage
        console.log('\n--- STAGE 2: LLM PARSING ---');
        const structuredData = await parsePrescriptionText(ocrResult.final_raw_text);
        
        console.log('\n--- FINAL STRUCTURED DATA ---');
        console.log(JSON.stringify(structuredData, null, 2));

        if (structuredData.medications && structuredData.medications.length > 0) {
            console.log('\n[SUCCESS] Pipeline successfully extracted medication data.');
        } else {
            console.log('\n[WARNING] No medications extracted. Check LLM output or OCR quality.');
        }

    } catch (err) {
        console.error('\n[FAILED] Pipeline test error:', err.message);
    }
}

testPipeline();
