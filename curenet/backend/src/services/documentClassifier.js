/**
 * ═══════════════════════════════════════════════════════════════════
 *  Document Classifier Service
 * ═══════════════════════════════════════════════════════════════════
 *
 *  Classifies clinical documents into one of:
 *    - "prescription"   → medicines / medication orders exist
 *    - "lab_report"     → test results / diagnostic values exist
 *    - "other"          → neither detected
 *
 *  Rules (strict, deterministic):
 *    1. If structured medications array has entries → prescription
 *    2. If structured lab_results array has entries → lab_report
 *    3. If raw text contains medicine indicators   → prescription
 *    4. If raw text contains lab indicators         → lab_report
 *    5. Otherwise → other
 *
 *  NEVER returns both. Prescription takes priority if ambiguous.
 */

// ─── Indicator patterns ──────────────────────────────────────────────────────

const PRESCRIPTION_INDICATORS = [
    /\b(?:Tab|Cap|Syp|Syr|Inj|Oint|Drop|Susp|Cream|Gel|Lotion)\.?\s/i,
    /\b(?:mg|mcg|ml)\b/i,
    /\b(?:OD|BD|TID|QID|HS|SOS)\b/,
    /\d\+\d\+\d/,                          // Indian dosage pattern: 1+0+1
    /\b(?:once|twice|thrice)\s*(?:daily|a\s*day)/i,
    /\b(?:before|after)\s*(?:food|meal)/i,
    /\b(?:morning|afternoon|night|evening|bedtime)\b/i,
    /\bRx\b/i,
    /\b(?:prescribed|prescription|dispense)\b/i,
];

const LAB_REPORT_INDICATORS = [
    /\b(?:hemoglobin|haemoglobin|hb|wbc|rbc|platelet|hematocrit)\b/i,
    /\b(?:esr|creatinine|urea|bun|glucose|blood\s*sugar)\b/i,
    /\b(?:hba1c|cholesterol|hdl|ldl|triglycerides|vldl)\b/i,
    /\b(?:sgpt|sgot|alt|ast|alp|alkaline\s*phosphatase)\b/i,
    /\b(?:bilirubin|albumin|total\s*protein|uric\s*acid)\b/i,
    /\b(?:sodium|potassium|chloride|calcium|phosphorus|magnesium)\b/i,
    /\b(?:tsh|t3|t4|free\s*t3|free\s*t4)\b/i,
    /\b(?:ferritin|iron|tibc|vitamin\s*d|vitamin\s*b12)\b/i,
    /\b(?:psa|crp|hs-crp|hiv|hbsag|anti\s*hcv)\b/i,
    /\b(?:fasting|random|post\s*prandial|pp)\b/i,
    /\b(?:reference\s*range|normal\s*range|ref\s*range)\b/i,
    /\b(?:test\s*name|test\s*result|investigation|pathology|laboratory)\b/i,
    /\b(?:report|diagnostic|specimen|sample)\b/i,
    /(?:g\/dl|mg\/dl|mmol\/l|u\/l|iu\/l|miu\/ml|ng\/ml|pg\/ml|μmol\/l|cells\/cumm|lakhs\/cumm|million\/cumm)/i,
];

/**
 * Classifies a document based on structured data and/or raw text.
 *
 * @param {Object} params
 * @param {Object} [params.structuredData] - Parsed structured data with medications/lab_results arrays
 * @param {string} [params.rawText]        - Raw OCR text for fallback classification
 * @returns {{ type: 'prescription'|'lab_report'|'other', confidence: number, reason: string }}
 */
function classifyDocument({ structuredData, rawText }) {
    // ─── Priority 1: Structured data arrays ──────────────────────────
    if (structuredData) {
        const hasMeds = Array.isArray(structuredData.medications) && structuredData.medications.length > 0;
        const hasLabs = Array.isArray(structuredData.lab_results) && structuredData.lab_results.length > 0;

        if (hasMeds && !hasLabs) {
            return { type: 'prescription', confidence: 0.95, reason: 'structured_medications_detected' };
        }
        if (hasLabs && !hasMeds) {
            return { type: 'lab_report', confidence: 0.95, reason: 'structured_lab_results_detected' };
        }
        if (hasMeds && hasLabs) {
            // Prescription takes priority per spec
            return { type: 'prescription', confidence: 0.85, reason: 'both_detected_prescription_priority' };
        }
    }

    // ─── Priority 2: Raw text pattern matching ───────────────────────
    if (rawText && rawText.length > 10) {
        const prescriptionScore = PRESCRIPTION_INDICATORS.reduce((score, rx) => {
            return score + (rx.test(rawText) ? 1 : 0);
        }, 0);

        const labScore = LAB_REPORT_INDICATORS.reduce((score, rx) => {
            return score + (rx.test(rawText) ? 1 : 0);
        }, 0);

        if (prescriptionScore > 2 && prescriptionScore > labScore) {
            return {
                type: 'prescription',
                confidence: Math.min(0.5 + prescriptionScore * 0.08, 0.9),
                reason: `text_pattern_match(rx=${prescriptionScore},lab=${labScore})`
            };
        }

        if (labScore > 2 && labScore > prescriptionScore) {
            return {
                type: 'lab_report',
                confidence: Math.min(0.5 + labScore * 0.08, 0.9),
                reason: `text_pattern_match(rx=${prescriptionScore},lab=${labScore})`
            };
        }

        if (prescriptionScore > 0 || labScore > 0) {
            const winnerType = prescriptionScore >= labScore ? 'prescription' : 'lab_report';
            return {
                type: winnerType,
                confidence: 0.45,
                reason: `weak_text_match(rx=${prescriptionScore},lab=${labScore})`
            };
        }
    }

    // ─── Fallback ────────────────────────────────────────────────────
    return { type: 'other', confidence: 0.3, reason: 'no_indicators_found' };
}

module.exports = { classifyDocument };
