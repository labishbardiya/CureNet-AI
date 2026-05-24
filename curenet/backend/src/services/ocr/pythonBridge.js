const { spawn } = require('child_process');
const path = require('path');

/**
 * Spawns the Python OCR engine to process an image.
 * Returns a Promise that resolves with the parsed OCR data.
 */
exports.runHybridOcr = (imagePath) => {
    return new Promise((resolve, reject) => {
        const pythonPath = 'python'; // Assumes 'python' is in the PATH
        const scriptPath = path.join(__dirname, 'ocr_engine.py');
        
        console.log(`[PythonBridge] Spawning OCR engine for: ${path.basename(imagePath)}`);
        
        const process = spawn(pythonPath, [scriptPath, imagePath]);
        
        let stdout = '';
        let stderr = '';
        
        process.stdout.on('data', (data) => {
            stdout += data.toString();
        });
        
        process.stderr.on('data', (data) => {
            stderr += data.toString();
            console.error(`[PythonBridge] Python stderr: ${data}`);
        });
        
        process.on('close', (code) => {
            if (code !== 0) {
                return reject(new Error(`Python process exited with code ${code}. Stderr: ${stderr}`));
            }
            
            try {
                // Extract JSON between tags if necessary, or parse directly
                const resultStart = stdout.indexOf('---RESULT_START---');
                const resultEnd = stdout.indexOf('---RESULT_END---');
                
                if (resultStart === -1 || resultEnd === -1) {
                    // Fallback to searching for JSON directly in stdout
                    const jsonMatch = stdout.match(/\{.*\}/s);
                    if (jsonMatch) {
                        return resolve(JSON.parse(jsonMatch[0]));
                    }
                    return reject(new Error('Failed to find JSON output in Python stdout.'));
                }
                
                const jsonStr = stdout.substring(resultStart + '---RESULT_START---'.length, resultEnd).trim();
                const data = JSON.parse(jsonStr);
                resolve(data);
            } catch (err) {
                reject(new Error(`Failed to parse Python output: ${err.message}`));
            }
        });
    });
};
