const fs = require('fs');
const { fromPath } = require('pdf2pic');
const path = require('path');

/**
 * Converts a PDF file into image paths to be consumed by Tesseract.
 * Tesseract typically digests images natively whereas PDFs require rendering bounding boxes.
 * Uses Ghostscript under the hood (Make sure Ghostscript is installed in the target environment).
 */
const convertPdfToImages = async (pdfFilePath) => {
    // We will save converted images in the same uploads directory
    const outputDirectory = path.dirname(pdfFilePath);
    const baseName = path.basename(pdfFilePath, path.extname(pdfFilePath));
    
    const options = {
        density: 300,           // good quality for OCR
        saveFilename: baseName, // the prefix
        savePath: outputDirectory,
        format: "png",
        width: 2048,            // large width scale
        height: 2048
    };

    try {
        const storeAsImage = fromPath(pdfFilePath, options);
        // Bulk convert. -1 refers to extracting all pages
        const results = await storeAsImage.bulk(-1, false);

        // Results array contains objects like { name, size, fileSize, path, page }
        const imagePaths = results.map(res => res.path);
        return imagePaths;
    } catch (err) {
        throw new Error('PDF Conversion Failed: ' + err.message);
    }
};

module.exports = {
    convertPdfToImages
};
