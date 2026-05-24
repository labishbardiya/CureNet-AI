/**
 * Cleans the raw text retrieved from OCR.
 * Attempts to preserve standard medical terms while removing garbled noise and excessive spacing.
 */
const cleanExtractedText = (rawText) => {
    if (!rawText) return '';

    // Remove non-printable characters and replace multiple newlines with single newlines
    let cleanText = rawText.replace(/[^\x20-\x7E\n]/g, '');
    cleanText = cleanText.replace(/\n{3,}/g, '\n\n');

    // Trim whitespace on each line
    cleanText = cleanText.split('\n').map(line => line.trim()).filter(line => line.length > 0).join('\n');

    return cleanText;
};

/**
 * Validates the extracted text and confidence constraints outlined by requirements.
 */
const validateExtraction = (cleanText, confidence) => {
    const warnings = [];

    if (cleanText.length < 20) {
        warnings.push('low_text_detected');
    }

    if (confidence < 0.5) {
        warnings.push('low_confidence');
    }

    // Determine unreadable quality by looking closely at spacing or gibberish.
    // If text consists of mostly special characters it's low quality
    const specialCharRatio = (cleanText.match(/[^a-zA-Z0-9\s]/g) || []).length / (cleanText.length || 1);
    if (specialCharRatio > 0.4) {
        warnings.push('low_quality_scan');
    }

    return warnings;
};

module.exports = {
    cleanExtractedText,
    validateExtraction
};
