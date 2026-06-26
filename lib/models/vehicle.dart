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
  final int? toPeriodKm;
  final int? toPeriodMonths;
  final String? equipmentType;
  final DateTime? equipmentToDate;
  final int? equipmentHours;
  final int? equipmentToPeriodHours;
  final int? equipmentToPeriodMonths;
  final String? notes;
  final String? departmentId;
  final String? sectionId;

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
    this.toPeriodKm,
    this.toPeriodMonths,
    this.equipmentType,
    this.equipmentToDate,
    this.equipmentHours,
    this.equipmentToPeriodHours,
    this.equipmentToPeriodMonths,
    this.notes,
    this.departmentId,
    this.sectionId,
  });

  String get brandModel => '$brand $model';

  // Вычисляемая дата следующего ТО автомобиля
  DateTime? get nextToDate {
    if (toDate == null || toPeriodMonths == null) return null;
    final d = toDate!;
    return DateTime(d.year, d.month + toPeriodMonths!, d.day);
  }

  // Вычисляемый пробег следующего ТО автомобиля
  int? get nextToMileage {
    if (toMileage == null || toPeriodKm == null) return null;
    return toMileage! + toPeriodKm!;
  }

  // Вычисляемая дата следующего ТО оборудования
  DateTime? get nextEquipmentToDate {
    if (equipmentToDate == null || equipmentToPeriodMonths == null) return null;
    final d = equipmentToDate!;
    return DateTime(d.year, d.month + equipmentToPeriodMonths!, d.day);
  }

  // Вычисляемые моточасы следующего ТО оборудования
  int? get nextEquipmentToHours {
    if (equipmentHours == null || equipmentToPeriodHours == null) return null;
    return equipmentHours! + equipmentToPeriodHours!;
  }

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
    toPeriodKm: json['to_period_km'],
    toPeriodMonths: json['to_period_months'],
    equipmentType: json['equipment_type'],
    equipmentToDate: json['equipment_to_date'] != null
        ? DateTime.parse(json['equipment_to_date']) : null,
    equipmentHours: json['equipment_hours'],
    equipmentToPeriodHours: json['equipment_to_period_hours'],
    equipmentToPeriodMonths: json['equipment_to_period_months'],
    notes: json['notes'],
    departmentId: json['department_id'],
    sectionId: json['section_id'],
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
    'to_period_km': toPeriodKm,
    'to_period_months': toPeriodMonths,
    'equipment_type': equipmentType,
    'equipment_to_date': equipmentToDate?.toIso8601String().split('T')[0],
    'equipment_hours': equipmentHours,
    'equipment_to_period_hours': equipmentToPeriodHours,
    'equipment_to_period_months': equipmentToPeriodMonths,
    'notes': notes,
    'department_id': departmentId,
    'section_id': sectionId,
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
