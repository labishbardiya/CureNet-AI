import cv2
import numpy as np
import easyocr
import json
import os
import sys
from transformers import pipeline, TrOCRProcessor, VisionEncoderDecoderModel
from PIL import Image

# Initialize OCR Engines
print("[PythonOCR] Initializing EasyOCR...")
reader = easyocr.Reader(['en', 'hi']) # English and Hindi

try:
    print("[PythonOCR] Initializing TrOCR...")
    # Using a small TrOCR model for handwriting
    processor = TrOCRProcessor.from_pretrained("microsoft/trocr-small-handwritten")
    model = VisionEncoderDecoderModel.from_pretrained("microsoft/trocr-small-handwritten")
    trocr_available = True
except Exception as e:
    print(f"[PythonOCR] TrOCR initialization failed: {e}. Falling back to EasyOCR only.")
    trocr_available = False

def preprocess_image(image_path):
    """Applies denoising and adaptive thresholding to improve OCR accuracy."""
    img = cv2.imread(image_path)
    if img is None:
        return None
    
    # Convert to grayscale
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # Denoising
    denoised = cv2.fastNlMeansDenoising(gray, h=10)
    
    # Adaptive Thresholding for faded text
    thresh = cv2.adaptiveThreshold(denoised, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
                                   cv2.THRESH_BINARY, 11, 2)
    
    # Save processed temp image
    processed_path = "temp_processed.png"
    cv2.imwrite(processed_path, thresh)
    return processed_path

def run_ocr(image_path):
    """Runs the hybrid OCR pipeline."""
    # Pre-process
    # processed_path = preprocess_image(image_path) # Sometimes raw is better for DL models
    
    # 1. EasyOCR for Printed Text & Layout
    print(f"[PythonOCR] Running EasyOCR on {image_path}...")
    easy_results = reader.readtext(image_path)
    
    printed_text_blocks = []
    for (bbox, text, prob) in easy_results:
        printed_text_blocks.append({
            "text": text,
            "confidence": float(prob),
            "bbox": [list(map(int, pt)) for pt in bbox]
        })
    
    # 2. TrOCR for Handwriting (on the whole image or large crops)
    generated_text = ""
    if trocr_available:
        try:
            print(f"[PythonOCR] Running TrOCR on {image_path}...")
            image = Image.open(image_path).convert("RGB")
            pixel_values = processor(images=image, return_tensors="pt").pixel_values
            generated_ids = model.generate(pixel_values)
            generated_text = processor.batch_decode(generated_ids, skip_special_tokens=True)[0]
        except Exception as e:
            print(f"[PythonOCR] TrOCR execution failed: {e}. Using EasyOCR results only.")
    else:
        print("[PythonOCR] TrOCR not available. Using EasyOCR results only.")
    
    # Merge results
    easyocr_text = " ".join([b["text"] for b in printed_text_blocks])
    final_text = easyocr_text
    if generated_text:
        final_text += "\nHandwritten: " + generated_text
    
    result = {
        "printed_blocks": printed_text_blocks,
        "handwritten_summary": generated_text,
        "final_raw_text": final_text
    }
    
    return result

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No image path provided"}))
        sys.exit(1)
        
    img_path = sys.argv[1]
    if not os.path.exists(img_path):
        print(json.dumps({"error": f"Path not found: {img_path}"}))
        sys.exit(1)
        
    try:
        final_data = run_ocr(img_path)
        print("---RESULT_START---")
        print(json.dumps(final_data))
        print("---RESULT_END---")
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)
