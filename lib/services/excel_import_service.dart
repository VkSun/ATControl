import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class VehicleImportRow {
  final String invNumber;
  final String brand;
  final String model;
  final String govNumber;

  const VehicleImportRow({
    required this.invNumber,
    required this.brand,
    required this.model,
    required this.govNumber,
  });
}

class DriverImportRow {
  final String tabNumber;
  final String lastName;
  final String firstName;
  final String? middleName;
  final String? licenseNumber;
  final DateTime? medicalExpiry;
  final List<String> vehicleInvNumbers;

  const DriverImportRow({
    required this.tabNumber,
    required this.lastName,
    required this.firstName,
    this.middleName,
    this.licenseNumber,
    this.medicalExpiry,
    this.vehicleInvNumbers = const [],
  });
}

class EngineHoursRow {
  final String invNumber;
  final int hours;

  const EngineHoursRow({required this.invNumber, required this.hours});
}

// ────────────────────────────────────────────────────────────────────────────
// Прямое чтение XLSX без пакета excel (обходит проблемы с numFmtId)
// ────────────────────────────────────────────────────────────────────────────

/// Конвертирует буквенный адрес колонки ("A"→0, "B"→1, "AA"→26 …)
int _colIndex(String cellRef) {
  final letters = cellRef.replaceAll(RegExp(r'\d'), '').toUpperCase();
  int col = 0;
  for (final ch in letters.codeUnits) {
    col = col * 26 + (ch - 64);
  }
  return col - 1;
}

String? _findFile(Archive archive, String name) {
  for (final f in archive) {
    if (f.name == name && f.isFile) {
      final raw = f.content;
      if (raw == null) return null;
      return utf8.decode(
          raw is List<int> ? raw : (raw as Uint8List),
          allowMalformed: true);
    }
  }
  return null;
}

/// Читает XLSX и возвращает матрицу строк (строки × колонки, sparse-safe).
List<List<String?>> readXlsx(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);

  // 1. Shared strings
  final sharedStrings = <String>[];
  final ssXml = _findFile(archive, 'xl/sharedStrings.xml');
  if (ssXml != null) {
    final doc = XmlDocument.parse(ssXml);
    for (final si in doc.findAllElements('si')) {
      sharedStrings.add(si.findAllElements('t').map((t) => t.innerText).join());
    }
  }

  // 2. Находим первый лист через workbook.xml + rels
  String sheetPath = 'xl/worksheets/sheet1.xml'; // fallback
  final wbXml = _findFile(archive, 'xl/workbook.xml');
  if (wbXml != null) {
    final rIdMatch = RegExp(r'r:id="(rId\d+)"').firstMatch(wbXml);
    if (rIdMatch != null) {
      final rId = rIdMatch.group(1)!;
      final relsXml = _findFile(archive, 'xl/_rels/workbook.xml.rels');
      if (relsXml != null) {
        final rm = RegExp('Id="$rId"[^>]*Target="([^"]+)"').firstMatch(relsXml);
        if (rm != null) {
          var target = rm.group(1)!;
          if (!target.startsWith('xl/')) target = 'xl/$target';
          sheetPath = target;
        }
      }
    }
  }

  // 3. Читаем лист
  final sheetXml = _findFile(archive, sheetPath);
  if (sheetXml == null) return [];

  final doc = XmlDocument.parse(sheetXml);
  final result = <List<String?>>[];

  for (final rowElem in doc.findAllElements('row')) {
    // Используем sparse-map чтобы правильно расставить колонки по адресу ячейки
    final sparse = <int, String?>{};
    int maxCol = 0;

    for (final c in rowElem.findAllElements('c')) {
      final ref = c.getAttribute('r') ?? '';
      final col = ref.isNotEmpty ? _colIndex(ref) : sparse.length;
      maxCol = max(maxCol, col + 1);

      final type = c.getAttribute('t');
      final vElem = c.findElements('v').firstOrNull;
      final raw = vElem?.innerText;

      if (raw == null) {
        sparse[col] = null;
        continue;
      }

      if (type == 's') {
        final idx = int.tryParse(raw) ?? 0;
        sparse[col] = idx < sharedStrings.length ? sharedStrings[idx] : null;
      } else if (type == 'inlineStr') {
        sparse[col] =
            c.findAllElements('t').map((t) => t.innerText).join();
      } else if (type == 'b') {
        sparse[col] = raw == '1' ? 'true' : 'false';
      } else {
        sparse[col] = raw; // число, серийная дата и т.д.
      }
    }

    final denseRow = List<String?>.filled(maxCol, null);
    for (final e in sparse.entries) {
      if (e.key < maxCol) denseRow[e.key] = e.value;
    }
    result.add(denseRow);
  }

  return result;
}

// ────────────────────────────────────────────────────────────────────────────
// Хелперы конвертации ячеек
// ────────────────────────────────────────────────────────────────────────────

String? _s(List<String?> row, int c) {
  if (c >= row.length) return null;
  final v = row[c]?.trim();
  return (v == null || v.isEmpty) ? null : v;
}

int? _i(List<String?> row, int c) {
  final v = _s(row, c);
  if (v == null) return null;
  return int.tryParse(v.replaceAll(RegExp(r'[^\d\-]'), ''));
}

double? _d(List<String?> row, int c) {
  final v = _s(row, c);
  if (v == null) return null;
  return double.tryParse(v.replaceAll(',', '.'));
}

DateTime? _dt(List<String?> row, int c) {
  final v = _s(row, c);
  if (v == null) return null;

  // dd.mm.yyyy
  final dots = v.split('.');
  if (dots.length == 3) {
    final d = int.tryParse(dots[0]);
    final m = int.tryParse(dots[1]);
    final y = int.tryParse(dots[2]);
    if (d != null && m != null && y != null && y > 1900) return DateTime(y, m, d);
  }

  // ISO
  final iso = DateTime.tryParse(v);
  if (iso != null) return iso;

  // Excel serial date (days since 1899-12-30)
  final serial = double.tryParse(v);
  if (serial != null && serial > 14000 && serial < 100000) {
    return DateTime(1899, 12, 30).add(Duration(days: serial.toInt()));
  }

  return null;
}

// ────────────────────────────────────────────────────────────────────────────
// Сервис импорта
// ────────────────────────────────────────────────────────────────────────────

class ExcelImportService {
  /// Файл "Список подвижного состава":
  /// col[0]=№, col[1]=гаражный №, col[2]=марка+модель, col[3]=госномер
  List<VehicleImportRow> parseVehicles(Uint8List bytes) {
    final rows = readXlsx(bytes);
    final results = <VehicleImportRow>[];

    for (final row in rows) {
      final counter = _i(row, 0);
      final invNum = _s(row, 1);
      if (counter == null || counter <= 0 || counter > 999) continue;
      if (invNum == null) continue;

      final brandModel = (_s(row, 2) ?? '').trim();
      final parts = brandModel.split(RegExp(r'\s+'));
      final brand = parts.isNotEmpty ? parts[0] : brandModel;
      final model = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      results.add(VehicleImportRow(
        invNumber: invNum,
        brand: brand,
        model: model,
        govNumber: _s(row, 3) ?? '',
      ));
    }

    return results;
  }

  /// Файл "Водители":
  /// col[0]=№, col[1]=таб.№, col[2]=ФИО, col[3]=№ удост.,
  /// col[8]=дата выдачи мед., col[9]=срок (лет), col[10]=гаражный № ТС
  /// Один водитель может встречаться несколько раз (несколько ТС) — собираем все.
  List<DriverImportRow> parseDrivers(Uint8List bytes) {
    final rows = readXlsx(bytes);

    // tabNumber → {данные водителя} + список ТС
    final driverMap = <String, DriverImportRow>{};
    final vehicleMap = <String, List<String>>{}; // tabNumber → [invNumbers]

    for (final row in rows) {
      final counter = _i(row, 0);
      final tabNum = _s(row, 1);
      if (counter == null || counter <= 0 || counter > 999) continue;
      if (tabNum == null) continue;

      final invNum = _s(row, 10);

      if (!driverMap.containsKey(tabNum)) {
        final fullName = (_s(row, 2) ?? '').trim();
        final parts = fullName.split(RegExp(r'\s+'));

        final medIssued = _dt(row, 8);
        final medYears = _i(row, 9);
        DateTime? medicalExpiry;
        if (medIssued != null && medYears != null && medYears > 0) {
          medicalExpiry = DateTime(
              medIssued.year + medYears, medIssued.month, medIssued.day);
        }

        driverMap[tabNum] = DriverImportRow(
          tabNumber: tabNum,
          lastName: parts.isNotEmpty ? parts[0] : '',
          firstName: parts.length > 1 ? parts[1] : '',
          middleName: parts.length > 2 ? parts.sublist(2).join(' ') : null,
          licenseNumber: _s(row, 3),
          medicalExpiry: medicalExpiry,
          vehicleInvNumbers: const [],
        );
        vehicleMap[tabNum] = [];
      }

      if (invNum != null && !vehicleMap[tabNum]!.contains(invNum)) {
        vehicleMap[tabNum]!.add(invNum);
      }
    }

    // Объединяем данные водителя с его ТС
    return driverMap.entries.map((e) {
      final d = e.value;
      return DriverImportRow(
        tabNumber: d.tabNumber,
        lastName: d.lastName,
        firstName: d.firstName,
        middleName: d.middleName,
        licenseNumber: d.licenseNumber,
        medicalExpiry: d.medicalExpiry,
        vehicleInvNumbers: vehicleMap[d.tabNumber] ?? [],
      );
    }).toList();
  }

  /// Файл "Моточасы":
  /// col[0]=гаражный № (>100000), col[4]=моточасы
  List<EngineHoursRow> parseEngineHours(Uint8List bytes) {
    final rows = readXlsx(bytes);
    final results = <EngineHoursRow>[];

    for (final row in rows) {
      final garageNum = _i(row, 0);
      if (garageNum == null || garageNum < 100000) continue;
      final hours = _d(row, 4);
      if (hours == null) continue;

      results.add(EngineHoursRow(
        invNumber: garageNum.toString(),
        hours: hours.round(),
      ));
    }

    return results;
  }
}
