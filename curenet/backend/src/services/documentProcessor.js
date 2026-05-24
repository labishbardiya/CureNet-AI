/**
 * ═══════════════════════════════════════════════════════════════════
 *  Unified Document Processor
 * ═══════════════════════════════════════════════════════════════════
 *
 *  Production-grade clinical document processing engine.
 *
 *  Pipeline:
 *    1. Classify document (prescription | lab_report | other)
 *    2. Generate ABDM-compliant FHIR R4 Bundle
 *    3. Generate UI-optimized structured output
 *    4. Self-validate for ABDM strict compliance
 *
 *  Returns ONLY: { fhir_bundle, ui_data }
 */

const { classifyDocument } = require('./documentClassifier');
const { buildABDMDocumentBundle, validateFhirBundle } = require('../utils/fhirBuilder');

/**
 * Processes structured clinical data through the complete pipeline.
 *
 * @param {Object} structuredData - Parsed clinical data from OCR/Vision
 * @param {string} [rawText]      - Raw OCR text for fallback classification
 * @returns {{ fhir_bundle: Object, ui_data: Object }}
 */
function processDocument(structuredData, rawText) {
    // ─── STEP 1: Classification ──────────────────────────────────────
    const classification = classifyDocument({ structuredData, rawText });
    const docType = classification.type;

    console.log(`[DocumentProcessor] Classified as: ${docType} (confidence: ${classification.confidence.toFixed(2)}, reason: ${classification.reason})`);

    // ─── STEP 2: FHIR Bundle Generation ──────────────────────────────
    let fhirBundle = null;

    if (docType === 'prescription' || docType === 'lab_report') {
        fhirBundle = buildABDMDocumentBundle(structuredData, docType);

        // ─── STEP 4: Self-Validation ─────────────────────────────────
        const validation = validateFhirBundle(fhirBundle);
        if (!validation.valid) {
            console.warn(`[DocumentProcessor] FHIR validation warnings:`);
            validation.errors.forEach(e => console.warn(`  ⚠ ${e}`));
        } else {
            console.log(`[DocumentProcessor] ✅ FHIR bundle validated — ${fhirBundle.entry.length} resources, 0 errors`);
        }
    }

    // ─── STEP 3: UI-Optimized Output ─────────────────────────────────
    const uiData = buildUiData(docType, structuredData);

    return {
        fhir_bundle: fhirBundle,
        ui_data: uiData
    };
}

/**
 * Builds the flat, UI-optimized output structure.
 * Rules:
 *   - prescriptions → populate medications[], lab_results stays []
 *   - lab_reports   → populate lab_results[], medications stays []
 *   - No mixing. No redundant fields. Flat structures only.
 */
function buildUiData(docType, data) {
    const nhcxCategory = docType === 'prescription' ? 'Pharmacy' : (docType === 'lab_report' ? 'Diagnostic' : 'Professional');

    const ui = {
        document_type: docType,
        nhcx_category: nhcxCategory,
        summary: {
            date: data.date || null,
            doctor: data.doctor_name || null,
            doctor_reg_no: data.doctor_reg_no || null,
            facility: data.clinic || null,
            facility_id: data.facility_id || null,
            patient: data.patient_name || null,
            gender: data.gender || null
        },
        medications: [],
        lab_results: [],
        documents: [{
            type: docType,
            date: data.date || null
        }]
    };

    if (docType === 'prescription') {
        // Deduplicate by name+frequency
        const seen = new Set();
        (data.medications || []).forEach(m => {
            const key = `${(m.name || '').toLowerCase()}|${m.frequency || ''}`;
            if (seen.has(key)) return;
            seen.add(key);

            ui.medications.push({
                name: m.name || '',
                dosage: m.dosage || '',
                frequency: m.frequency || '',
                duration: m.duration || ''
            });
        });
    }

    if (docType === 'lab_report') {
        // Deduplicate by test_name
        const seen = new Set();
        (data.lab_results || []).forEach(t => {
            const key = (t.test_name || '').toLowerCase();
            if (seen.has(key)) return;
            seen.add(key);

            ui.lab_results.push({
                test_name: t.test_name || '',
                value: t.value || '',
                unit: t.unit || '',
                reference_range: t.reference_range || ''
            });
        });
    }

    // Optional enrichments (only if available, don't add empty)
    if (data.diagnosis) ui.summary.diagnosis = data.diagnosis;
    if (data.chief_complaint) ui.summary.chief_complaint = data.chief_complaint;
    if (data.vitals) ui.summary.vitals = data.vitals;
    if (data.investigations) ui.summary.investigations = data.investigations;
    if (data.follow_up) {
        ui.follow_up = {
            date: data.follow_up.date || null,
            advice: data.follow_up.advice || []
        };
    }

    return ui;
}

module.exports = { processDocument, buildUiData };
