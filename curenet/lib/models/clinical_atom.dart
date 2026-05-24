import 'package:objectbox/objectbox.dart';

@Entity()
class ClinicalAtom {
  @Id()
  int id = 0;

  @Index()
  String type; // 'medication' | 'observation' | 'condition'
  
  String name;
  String value;
  String unit;
  
  @Index()
  String date; // YYYY-MM-DD
  
  String metadataJson; // JSON string for extra fields

  ClinicalAtom({
    required this.type,
    required this.name,
    required this.value,
    this.unit = '',
    required this.date,
    this.metadataJson = '{}',
  });
}
