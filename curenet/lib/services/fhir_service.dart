import 'package:fhir/r4.dart';

/// Service to transform CureNet records into ABDM-compliant FHIR R4 Bundles (M2).
class FhirService {
  /// Create a basic FHIR Bundle for a Prescription.
  /// First resource is always a Composition.
  static Bundle createPrescriptionBundle({
    required String patientId,
    required String doctorId,
    required String prescriptionText,
    required DateTime date,
  }) {
    final composition = Composition.fromJson({
      'resourceType': 'Composition',
      'id': 'comp-${DateTime.now().millisecondsSinceEpoch}',
      'status': 'final',
      'type': {
        'coding': [
          {
            'system': 'http://snomed.info/sct',
            'code': '440545006',
            'display': 'Prescription record',
          },
        ],
      },
      'subject': {'reference': 'Patient/$patientId'},
      'date': date.toUtc().toIso8601String(),
      'author': [
        {'reference': 'Practitioner/$doctorId'}
      ],
      'title': 'Prescription',
      'section': [
        {
          'title': 'Prescription Details',
          'text': {
            'status': 'generated',
            'div': '<div xmlns="http://www.w3.org/1999/xhtml">$prescriptionText</div>',
          },
        },
      ],
    });

    return Bundle.fromJson({
      'resourceType': 'Bundle',
      'id': 'bundle-${DateTime.now().millisecondsSinceEpoch}',
      'type': 'document',
      'entry': [
        {'resource': composition.toJson()},
      ],
    });
  }
}
