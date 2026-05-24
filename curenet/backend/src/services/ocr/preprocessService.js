const sharp = require('sharp');
const path = require('path');
const fs = require('fs');

/**
 * Enhances the target image by applying grayscale, normalizing contrast, 
 * and boosting readibility to improve Tesseract's confidence scores.
 */
const preprocessImage = async (inputImagePath) => {
    const ext = path.extname(inputImagePath);
    const directory = path.dirname(inputImagePath);
    const baseName = path.basename(inputImagePath, ext);
    
    const processedImagePath = path.join(directory, `${baseName}_processed${ext}`);

    try {
        await sharp(inputImagePath)
            .grayscale()             // Remove color artifacts
            .normalize()             // Enhance contrast
            .sharpen()               // Enhance edges (letters)
            // Apply slight blur to remove extreme granular noise, highly effective against poor scans
            .median(3)               
            .toFile(processedImagePath);
            
        return processedImagePath;
    } catch (error) {
        throw new Error('Image Preprocessing Failed: ' + error.message);
    }
};

module.exports = {
    preprocessImage
};
