class Vehicle {
  final String id;
  final String invNumber;
  final String brand;
  final String model;
  final String govNumber;
  final int? year;
  final String? color;
  final String? vin;
  final DateTime? inspectionDate;
  final DateTime? insuranceDate;
  final DateTime? specialPermitDate;
  final DateTime? toDate;
  final int? toMileage;
  final String? equipmentType;
  final DateTime? equipmentToDate;
  final int? equipmentHours;
  final String? notes;

  Vehicle({
    required this.id,
    required this.invNumber,
    required this.brand,
    required this.model,
    required this.govNumber,
    this.year,
    this.color,
    this.vin,
    this.inspectionDate,
    this.insuranceDate,
    this.specialPermitDate,
    this.toDate,
    this.toMileage,
    this.equipmentType,
    this.equipmentToDate,
    this.equipmentHours,
    this.notes,
  });

  String get brandModel => '$brand $model';

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
    id: json['id'],
    invNumber: json['inv_number'],
    brand: json['brand'],
    model: json['model'],
    govNumber: json['gov_number'],
    year: json['year'],
    color: json['color'],
    vin: json['vin'],
    inspectionDate: json['inspection_date'] != null
        ? DateTime.parse(json['inspection_date']) : null,
    insuranceDate: json['insurance_date'] != null
        ? DateTime.parse(json['insurance_date']) : null,
    specialPermitDate: json['special_permit_date'] != null
        ? DateTime.parse(json['special_permit_date']) : null,
    toDate: json['to_date'] != null
        ? DateTime.parse(json['to_date']) : null,
    toMileage: json['to_mileage'],
    equipmentType: json['equipment_type'],
    equipmentToDate: json['equipment_to_date'] != null
        ? DateTime.parse(json['equipment_to_date']) : null,
    equipmentHours: json['equipment_hours'],
    notes: json['notes'],
  );

  Map<String, dynamic> toJson() => {
    'inv_number': invNumber,
    'brand': brand,
    'model': model,
    'gov_number': govNumber,
    'year': year,
    'color': color,
    'vin': vin,
    'inspection_date': inspectionDate?.toIso8601String().split('T')[0],
    'insurance_date': insuranceDate?.toIso8601String().split('T')[0],
    'special_permit_date': specialPermitDate?.toIso8601String().split('T')[0],
    'to_date': toDate?.toIso8601String().split('T')[0],
    'to_mileage': toMileage,
    'equipment_type': equipmentType,
    'equipment_to_date': equipmentToDate?.toIso8601String().split('T')[0],
    'equipment_hours': equipmentHours,
    'notes': notes,
  };

  static int dateStatus(DateTime? date) {
    if (date == null) return 0;
    final now = DateTime.now();
    final diff = date.difference(now).inDays;
    if (diff < 0) return 3;
    if (diff <= 7) return 2;
    if (diff <= 30) return 1;
    return 0;
  }
}