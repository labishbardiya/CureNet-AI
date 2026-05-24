const { parsePrescriptionText } = require('../src/services/ocr/parserService');
const { normalizeMedicineName } = require('../src/services/ocr/normalizationService');
const { buildABDMDocumentBundle } = require('../src/utils/fhirBuilder');

/**
 * Synthetic Test Suite: Step 10
 * Validates the pipeline robustness against messy handwriting simulations.
 */
const runSyntheticTests = () => {
    console.log('\n🧪 --- CURENET OCR PIPELINE: SYNTHETIC TEST SUITE --- 🧪\n');

    const testCases = [
        {
            name: "Clean Single Medicine",
            input: "Paracetaml 500mg once daily for 5 days",
            expectedMedicine: "Paracetamol"
        },
        {
            name: "Messy handwriting (Spelling errors)",
            input: "Amoxiclin 250mg 1-0-1 for 7 days",
            expectedMedicine: "Amoxicillin"
        },
        {
            name: "Common Brand Name",
            input: "Calpol 650mg SOS",
            expectedMedicine: "Calpol"
        },
        {
            name: "Multiple Medicines",
            input: "Azithromycin 500mg OD x 3 days\nPantoprazole 40mg before food",
            expectedCount: 2
        }
    ];

    let passed = 0;

    testCases.forEach((tc, index) => {
        console.log(`Test #${index + 1}: ${tc.name}`);
        const result = parsePrescriptionText(tc.input);
        
        const firstMed = result.medications[0];
        let testPassed = true;

        if (tc.expectedMedicine && firstMed.name !== tc.expectedMedicine) {
            console.error(`  ❌ Failed: Expected ${tc.expectedMedicine}, got ${firstMed.name}`);
            testPassed = false;
        }

        if (tc.expectedCount && result.medications.length !== tc.expectedCount) {
            console.error(`  ❌ Failed: Expected ${tc.expectedCount} meds, got ${result.medications.length}`);
            testPassed = false;
        }

        if (testPassed) {
            console.log(`  ✅ Passed! Extracted: ${firstMed.name} (${firstMed.dosage})`);
            passed++;
        }
    });

    console.log(`\n--- SUMMARY: ${passed}/${testCases.length} Tests Passed ---\n`);

    // Validate FHIR Generation
    console.log('🏥 Validating FHIR R4 Bundle Generation...');
    const mockStructured = parsePrescriptionText("Dolo 650 BD for 3 days");
    const bundle = buildABDMDocumentBundle(mockStructured);
    
    if (bundle.resourceType === "Bundle" && bundle.entry.length >= 5) {
        console.log('  ✅ FHIR Bundle structure validated (ABDM Compliant).');
    } else {
        console.error('  ❌ FHIR Bundle validation failed.');
    }
};

runSyntheticTests();
