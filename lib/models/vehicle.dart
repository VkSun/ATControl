import '../utils/date_utils.dart';

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

  // Только даты сроков — единственное, что сейчас правится точечно
  // (см. ExpiryEditDialog). Ручная пересборка Vehicle(...) полем за полем
  // рискует незаметно потерять новые поля при добавлении — отсюда copyWith.
  Vehicle copyWith({
    DateTime? inspectionDate,
    DateTime? insuranceDate,
    DateTime? specialPermitDate,
    DateTime? toDate,
    DateTime? equipmentToDate,
  }) => Vehicle(
    id: id,
    invNumber: invNumber,
    brand: brand,
    model: model,
    govNumber: govNumber,
    year: year,
    color: color,
    vin: vin,
    inspectionDate: inspectionDate ?? this.inspectionDate,
    insuranceDate: insuranceDate ?? this.insuranceDate,
    specialPermitDate: specialPermitDate ?? this.specialPermitDate,
    toDate: toDate ?? this.toDate,
    toMileage: toMileage,
    toPeriodKm: toPeriodKm,
    toPeriodMonths: toPeriodMonths,
    equipmentType: equipmentType,
    equipmentToDate: equipmentToDate ?? this.equipmentToDate,
    equipmentHours: equipmentHours,
    equipmentToPeriodHours: equipmentToPeriodHours,
    equipmentToPeriodMonths: equipmentToPeriodMonths,
    notes: notes,
    departmentId: departmentId,
    sectionId: sectionId,
  );

  // Все пять типов дат истечения для единого обхода
  List<({String type, DateTime? date})> expiryDates() => [
    (type: 'Техосмотр', date: inspectionDate),
    (type: 'Страховка', date: insuranceDate),
    (type: 'Спец. разрешение', date: specialPermitDate),
    (type: 'ТО автомобиля', date: nextToDate),
    (type: 'ТО оборудования', date: nextEquipmentToDate),
  ];

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

  /// Колонки для select() — ровно поля, которые читает fromJson.
  static const columns =
      'id, inv_number, brand, model, gov_number, year, color, vin, '
      'inspection_date, insurance_date, special_permit_date, '
      'to_date, to_mileage, to_period_km, to_period_months, '
      'equipment_type, equipment_to_date, equipment_hours, '
      'equipment_to_period_hours, equipment_to_period_months, '
      'notes, department_id, section_id';

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
    id: json['id'] as String,
    invNumber: json['inv_number'] as String,
    brand: json['brand'] as String,
    model: json['model'] as String,
    govNumber: json['gov_number'] as String,
    year: json['year'] as int?,
    color: json['color'] as String?,
    vin: json['vin'] as String?,
    inspectionDate: json['inspection_date'] != null
        ? DateTime.parse(json['inspection_date'] as String) : null,
    insuranceDate: json['insurance_date'] != null
        ? DateTime.parse(json['insurance_date'] as String) : null,
    specialPermitDate: json['special_permit_date'] != null
        ? DateTime.parse(json['special_permit_date'] as String) : null,
    toDate: json['to_date'] != null
        ? DateTime.parse(json['to_date'] as String) : null,
    toMileage: json['to_mileage'] as int?,
    toPeriodKm: json['to_period_km'] as int?,
    toPeriodMonths: json['to_period_months'] as int?,
    equipmentType: json['equipment_type'] as String?,
    equipmentToDate: json['equipment_to_date'] != null
        ? DateTime.parse(json['equipment_to_date'] as String) : null,
    equipmentHours: json['equipment_hours'] as int?,
    equipmentToPeriodHours: json['equipment_to_period_hours'] as int?,
    equipmentToPeriodMonths: json['equipment_to_period_months'] as int?,
    notes: json['notes'] as String?,
    departmentId: json['department_id'] as String?,
    sectionId: json['section_id'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'inv_number': invNumber,
    'brand': brand,
    'model': model,
    'gov_number': govNumber,
    'year': year,
    'color': color,
    'vin': vin,
    'inspection_date': dateStr(inspectionDate),
    'insurance_date': dateStr(insuranceDate),
    'special_permit_date': dateStr(specialPermitDate),
    'to_date': dateStr(toDate),
    'to_mileage': toMileage,
    'to_period_km': toPeriodKm,
    'to_period_months': toPeriodMonths,
    'equipment_type': equipmentType,
    'equipment_to_date': dateStr(equipmentToDate),
    'equipment_hours': equipmentHours,
    'equipment_to_period_hours': equipmentToPeriodHours,
    'equipment_to_period_months': equipmentToPeriodMonths,
    'notes': notes,
    'department_id': departmentId,
    'section_id': sectionId,
  };

  /// Худший (максимальный) статус среди всех дат истечения —
  /// для цветового индикатора строки в списке.
  int worstDateStatus() => expiryDates()
      .map((e) => dateStatus(e.date))
      .fold(0, (a, b) => a > b ? a : b);

  static int dateStatus(DateTime? date) {
    if (date == null) return 0;
    final diff = daysUntil(date);
    if (diff < 0) return 4;   // expired → red
    if (diff <= 7) return 3;  // 1-7 days → red
    if (diff <= 14) return 2; // 7-14 days → amber
    if (diff <= 30) return 1; // 14-30 days → green
    return 0;
  }
}
