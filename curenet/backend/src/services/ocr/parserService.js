const { spawn } = require('child_process');
const path = require('path');
const { normalizeMedicineName } = require('./normalizationService');

/**
 * Spawns the Python LLM parser to structure OCR text.
 */
const runLlmParser = (rawText) => {
    return new Promise((resolve, reject) => {
        const pythonPath = 'python';
        const scriptPath = path.join(__dirname, 'llm_parser.py');
        
        console.log('[LLMBridge] Spawning LLM parser...');
        const process = spawn(pythonPath, [scriptPath, rawText]);
        
        let stdout = '';
        process.stdout.on('data', (data) => (stdout += data.toString()));
        process.on('close', (code) => {
            try {
                const resultStart = stdout.indexOf('---RESULT_START---');
                const resultEnd = stdout.indexOf('---RESULT_END---');
                if (resultStart === -1) return resolve(null); // Fallback to regex
                
                const jsonStr = stdout.substring(resultStart + '---RESULT_START---'.length, resultEnd).trim();
                resolve(JSON.parse(jsonStr));
            } catch (err) {
                resolve(null);
            }
        });
    });
};

/**
 * Extracts structured medical data from raw OCR text.
 * Now uses a hybrid approach: Local LLM with Regex Fallback.
 */
exports.parsePrescriptionText = async (rawText) => {
    // 1. Try Local LLM Parser first (as requested)
    try {
        const llmResult = await runLlmParser(rawText);
        if (llmResult && !llmResult.error && llmResult.medications) {
            console.log('[Parser] Successfully parsed using Local LLM.');
            return llmResult;
        }
    } catch (err) {
        console.warn('[Parser] LLM parsing failed, falling back to regex:', err.message);
    }

    // 2. Regex Fallback (Original Logic)
    console.log('[Parser] Falling back to Regex-based extraction.');
    const lines = rawText.split('\n').filter(l => l.trim().length > 3);
    const medications = [];

    for (const line of lines) {
        const dosagePattern = /(\d+\s*(mg|ml|mcg|tablets?|caps?|units?|drops?))/i;
        const frequencyPattern = /(once daily|twice daily|thrice daily|OD|BD|TID|QID|HS|SOS|before food|after food|1-0-1|0-1-0|1-1-1)/i;
        const durationPattern = /(\d+\s*(days|weeks|months|days?))/i;

        const dosageMatch = line.match(dosagePattern);
        const freqMatch = line.match(frequencyPattern);
        const durationMatch = line.match(durationPattern);

        let medicineRaw = line;
        const firstMatchIndex = [dosageMatch, freqMatch, durationMatch]
            .filter(m => m)
            .reduce((min, m) => Math.min(min, m.index), line.length);
        
        medicineRaw = line.substring(0, firstMatchIndex).trim().replace(/^[^\w]+/, '');
        if (medicineRaw.length < 3) continue;

        const normalizedName = normalizeMedicineName(medicineRaw);
        
        medications.push({
            raw_text: line.trim(),
            name: normalizedName,
            dosage: dosageMatch ? dosageMatch[0] : 'unclear',
            frequency: freqMatch ? freqMatch[0] : 'unclear',
            duration: durationMatch ? durationMatch[0] : 'unclear',
            confidence: 0.7
        });
    }

    return {
        patient_name: 'unclear',
        doctor_name: 'unclear',
        date: new Date().toISOString().split('T')[0],
        medications
    };
};
