"""
═══════════════════════════════════════════════════════════════════
 Gemma 4 E4B Local LLM Parser — Edge-First Clinical Data Extraction
═══════════════════════════════════════════════════════════════════

 Uses Gemma 4 E4B (Effective 4B) for on-device/workstation parsing
 and validation of raw OCR text into structured clinical JSON.

 Architecture:
   • Primary: Gemma 4 E4B via Hugging Face Transformers
     → Per-Layer Embeddings (PLE) pack frontier-level logic into
       a tiny memory footprint
     → 128K context window for massive medical data logs
     → Runs natively offline to conserve device RAM and battery

   • Fallback: Gemma 4 27B (if workstation resources allow)

 This parser is used as a FALLBACK when the Vision LLM API
 (Gemma 4 31B via Ollama) is unavailable. It processes raw OCR
 text extracted by EasyOCR/TrOCR into structured clinical JSON.
═══════════════════════════════════════════════════════════════════
"""

import json
import sys
import os
from transformers import pipeline
import torch

# ─── Gemma 4 Model Configuration ─────────────────────────────────
# Primary: Gemma 4 E4B — lightweight edge model with PLE architecture
MODEL_ID = os.environ.get("GEMMA4_MODEL_ID", "google/gemma-4-4b-it")
# Alternative: Gemma 4 27B for workstations with more resources
# MODEL_ID = "google/gemma-4-27b-it"

print(f"[LLMParser] Loading Gemma 4 E4B model ({MODEL_ID})...")
try:
    pipe = pipeline(
        "text-generation", 
        model=MODEL_ID, 
        torch_dtype=torch.bfloat16 if torch.cuda.is_available() else torch.float32,
        device_map="auto" if torch.cuda.is_available() else "cpu"
    )
except Exception as e:
    print(json.dumps({"error": f"Failed to load Gemma 4 E4B: {str(e)}"}))
    sys.exit(1)

def parse_text(raw_text):
    """
    Zero-shot structure prompt for clinical data extraction.
    Converts raw OCR text into FHIR R4-compatible structured JSON
    containing Patient, Observation, and DiagnosticReport fields.
    """
    prompt = f"""<start_of_turn>user
You are a medical data extraction assistant powered by Gemma 4.
Convert the following OCR text from a clinical document into structured JSON format.

Extract:
- patient_name, doctor_name, date, clinic
- medications: list of {{name, dosage, frequency, duration}}
- lab_results: list of {{test_name, value, unit, reference_range}}
- diagnosis, chief_complaint, vitals

If information is missing or unclear, use 'unclear'.
For Indian prescriptions: '1+0+1' means morning+afternoon+night dosage.
Output ONLY valid JSON. No explanations.

OCR Text:
{raw_text}
<end_of_turn>
<start_of_turn>model
"""
    
    outputs = pipe(prompt, max_new_tokens=512, do_sample=True, temperature=0.1, top_k=50, top_p=0.95)
    full_text = outputs[0]["generated_text"]
    
    # Extract JSON part from model output
    try:
        json_start = full_text.find("{", full_text.find("<start_of_turn>model"))
        json_end = full_text.rfind("}") + 1
        json_str = full_text[json_start:json_end]
        return json.loads(json_str)
    except Exception as e:
        return {"error": "Failed to parse JSON from Gemma 4 output", "raw": full_text}

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No text provided"}))
        sys.exit(1)
        
    raw_input = sys.argv[1]
    
    try:
        result = parse_text(raw_input)
        print("---RESULT_START---")
        print(json.dumps(result))
        print("---RESULT_END---")
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)
