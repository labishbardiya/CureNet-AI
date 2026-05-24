const path = require('path');
const { runHybridOcr } = require('../src/services/ocr/pythonBridge');
const { parsePrescriptionText } = require('../src/services/ocr/parserService');

async function runBenchmark() {
    const imagePath = path.resolve(__dirname, '../../image.png');
    console.log(`[Benchmark] Testing current (Non-Optimized) pipeline on: ${imagePath}`);
    
    const startTime = Date.now();

    try {
        console.log('\n--- STARTING OCR STAGE ---');
        const ocrStartTime = Date.now();
        const ocrResult = await runHybridOcr(imagePath);
        const ocrEndTime = Date.now();
        console.log(`OCR took: ${(ocrEndTime - ocrStartTime) / 1000}s`);

        console.log('\n--- STARTING LLM PARSING STAGE ---');
        const parseStartTime = Date.now();
        const structuredData = await parsePrescriptionText(ocrResult.final_raw_text);
        const parseEndTime = Date.now();
        console.log(`LLM Parsing took: ${(parseEndTime - parseStartTime) / 1000}s`);

        const totalTime = Date.now() - startTime;
        console.log('\n--- BENCHMARK RESULTS ---');
        console.log(`Total Processing Time: ${totalTime / 1000}s`);
        console.log('Result:', JSON.stringify(structuredData, null, 2).substring(0, 200) + '...');

    } catch (err) {
        console.error('\n[FAILED] Benchmark error:', err.message);
    }
}

runBenchmark();
