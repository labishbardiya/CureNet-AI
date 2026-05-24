const { pipeline } = require('@xenova/transformers');
const path = require('path');

let ocrPipeline = null;

/**
 * Initializes the TrOCR pipeline. Loads the model from the Hugging Face Hub if not cached.
 */
const initPipeline = async () => {
    if (!ocrPipeline) {
        console.log('[TrOCR] Initializing Microsoft TrOCR handwritten pipeline...');
        ocrPipeline = await pipeline('image-to-text', 'Xenova/trocr-small-handwritten', {
            device: 'cpu' // Default to CPU for maximum compatibility
        });
    }
    return ocrPipeline;
};

/**
 * Extracts handwritten text from a single image using TrOCR.
 * Returns raw text and a confidence score estimate.
 */
exports.extractHandwriting = async (imagePath) => {
    try {
        const pipe = await initPipeline();
        
        console.log(`[TrOCR] Running extraction on: ${path.basename(imagePath)}`);
        
        // TrOCR returns a list with { generated_text }
        const result = await pipe(imagePath);
        
        // transformers.js for TrOCR doesn't return per-token confidence easily yet, 
        // we use a baseline if generated_text exists.
        const text = result[0]?.generated_text || '';
        
        if (!text || text.trim().length === 0) {
            return { raw_text: 'unclear', confidence: 0.0 };
        }

        return {
            raw_text: text.trim(),
            confidence: 0.85 // Baseline for successful generation
        };
    } catch (err) {
        console.error('[TrOCR] Extraction error:', err.message);
        return { raw_text: 'unclear', confidence: 0.0, error: err.message };
    }
};
