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
  final String? vehicleId;
  final String? notes;

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
    this.vehicleId,
    this.notes,
  });

  String get fullName => '$lastName $firstName${middleName != null ? ' $middleName' : ''}';
  String get shortName => '$lastName ${firstName[0]}.${middleName != null ? '${middleName![0]}.' : ''}';

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
    vehicleId: json['vehicle_id'],
    notes: json['notes'],
  );

  Map<String, dynamic> toJson() => {
    'tab_number': tabNumber,
    'last_name': lastName,
    'first_name': firstName,
    'middle_name': middleName,
    'birth_date': birthDate?.toIso8601String().split('T')[0],
    'phone': phone,
    'address': address,
    'license_number': licenseNumber,
    'license_expiry': licenseExpiry?.toIso8601String().split('T')[0],
    'license_categories': licenseCategories,
    'medical_expiry': medicalExpiry?.toIso8601String().split('T')[0],
    'vehicle_id': vehicleId,
    'notes': notes,
  };
}