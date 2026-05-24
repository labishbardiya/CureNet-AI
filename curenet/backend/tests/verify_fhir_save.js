const path = require('path');
const fs = require('fs');
const Record = require('../src/models/recordModel');
const { runJob } = require('../src/services/workerService');

async function verifySave() {
    console.log('[Verify] Testing FHIR bundle file saving...');
    
    // Create a mock record
    const jobId = 'test-' + Date.now();
    const imagePath = path.resolve(__dirname, '../../image.png');
    
    if (!fs.existsSync(imagePath)) {
        console.error(`[Error] image.png not found at ${imagePath}`);
        return;
    }

    const mockRecord = new Record({
        jobId: jobId,
        status: 'processing',
        filePath: imagePath
    });

    try {
        await runJob(mockRecord);
        
        const outputDir = path.resolve(__dirname, '../output_bundles');
        const expectedFile = path.join(outputDir, `fhir_bundle_${jobId}.json`);
        
        if (fs.existsSync(expectedFile)) {
            console.log(`\n[SUCCESS] FHIR Bundle saved successfully at: ${expectedFile}`);
            const content = fs.readFileSync(expectedFile, 'utf8');
            const bundle = JSON.parse(content);
            console.log(`Bundle Resource Type: ${bundle.resourceType}`);
            console.log(`Medication Request Count: ${bundle.entry.filter(e => e.resource.resourceType === 'MedicationRequest').length}`);
        } else {
            console.error(`\n[FAILED] Expected file not found: ${expectedFile}`);
        }
    } catch (err) {
        console.error(`\n[ERROR] Verification failed: ${err.message}`);
    }
}

verifySave();
