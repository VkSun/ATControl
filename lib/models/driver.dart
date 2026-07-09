import '../utils/date_utils.dart';
import 'vehicle.dart';

class Driver {
  final String id;
  final String tabNumber;
  final String lastName;
  final String firstName;
  final String? middleName;
  final DateTime? birthDate;
  final String? phone;
  final String? address;
  final String? licenseNumber;
  final DateTime? licenseExpiry;
  final String? licenseCategories;
  final DateTime? medicalExpiry;
  final List<String> vehicleIds;
  final String? notes;
  final String? departmentId;
  final String? sectionId;

  Driver({
    required this.id,
    required this.tabNumber,
    required this.lastName,
    required this.firstName,
    this.middleName,
    this.birthDate,
    this.phone,
    this.address,
    this.licenseNumber,
    this.licenseExpiry,
    this.licenseCategories,
    this.medicalExpiry,
    this.vehicleIds = const [],
    this.notes,
    this.departmentId,
    this.sectionId,
  });

  String? get vehicleId => vehicleIds.firstOrNull;

  Driver copyWith({List<String>? vehicleIds}) => Driver(
    id: id,
    tabNumber: tabNumber,
    lastName: lastName,
    firstName: firstName,
    middleName: middleName,
    birthDate: birthDate,
    phone: phone,
    address: address,
    licenseNumber: licenseNumber,
    licenseExpiry: licenseExpiry,
    licenseCategories: licenseCategories,
    medicalExpiry: medicalExpiry,
    vehicleIds: vehicleIds ?? this.vehicleIds,
    notes: notes,
    departmentId: departmentId,
    sectionId: sectionId,
  );

  String get fullName => '$lastName $firstName${middleName != null ? ' $middleName' : ''}';
  String get shortName {
    // Имя/отчество могут быть пустыми (импорт из Excel) — без RangeError.
    var s = lastName;
    if (firstName.isNotEmpty) s += ' ${firstName[0]}.';
    if (middleName != null && middleName!.isNotEmpty) {
      s += firstName.isNotEmpty ? '${middleName![0]}.' : ' ${middleName![0]}.';
    }
    return s;
  }

  /// Худший статус по датам удостоверения и медсправки
  /// (шкала Vehicle.dateStatus) — для цветового индикатора в списке.
  int worstDateStatus() {
    final license = Vehicle.dateStatus(licenseExpiry);
    final medical = Vehicle.dateStatus(medicalExpiry);
    return license > medical ? license : medical;
  }

  /// Колонки для select() — ровно поля, которые читает fromJson.
  static const columns =
      'id, tab_number, last_name, first_name, middle_name, birth_date, '
      'phone, address, license_number, license_expiry, license_categories, '
      'medical_expiry, vehicle_ids, notes, department_id, section_id';

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
    id: json['id'],
    tabNumber: json['tab_number'],
    lastName: json['last_name'],
    firstName: json['first_name'],
    middleName: json['middle_name'],
    birthDate: json['birth_date'] != null ? DateTime.parse(json['birth_date']) : null,
    phone: json['phone'],
    address: json['address'],
    licenseNumber: json['license_number'],
    licenseExpiry: json['license_expiry'] != null ? DateTime.parse(json['license_expiry']) : null,
    licenseCategories: json['license_categories'],
    medicalExpiry: json['medical_expiry'] != null ? DateTime.parse(json['medical_expiry']) : null,
    vehicleIds: (json['vehicle_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
    notes: json['notes'],
    departmentId: json['department_id'],
    sectionId: json['section_id'],
  );

  Map<String, dynamic> toJson() => {
    'tab_number': tabNumber,
    'last_name': lastName,
    'first_name': firstName,
    'middle_name': middleName,
    'birth_date': dateStr(birthDate),
    'phone': phone,
    'address': address,
    'license_number': licenseNumber,
    'license_expiry': dateStr(licenseExpiry),
    'license_categories': licenseCategories,
    'medical_expiry': dateStr(medicalExpiry),
    'vehicle_ids': vehicleIds,
    'notes': notes,
    'department_id': departmentId,
    'section_id': sectionId,
  };
}