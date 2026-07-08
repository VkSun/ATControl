import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:atcontrol/services/excel_import_service.dart';

/// Собирает минимальный XLSX: только лист (fallback-путь xl/worksheets/sheet1.xml)
/// и, опционально, sharedStrings.
Uint8List xlsxBytes(String sheetInnerXml, {String? sharedStringsXml}) {
  final archive = Archive();
  void add(String name, String content) {
    final data = utf8.encode(content);
    archive.addFile(ArchiveFile(name, data.length, data));
  }

  add('xl/worksheets/sheet1.xml',
      '<?xml version="1.0"?><worksheet><sheetData>$sheetInnerXml</sheetData></worksheet>');
  if (sharedStringsXml != null) {
    add('xl/sharedStrings.xml',
        '<?xml version="1.0"?><sst>$sharedStringsXml</sst>');
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

/// Ячейка с inline-строкой.
String cell(String ref, String text) =>
    '<c r="$ref" t="inlineStr"><is><t>$text</t></is></c>';

/// Числовая ячейка.
String num_(String ref, Object value) => '<c r="$ref"><v>$value</v></c>';

void main() {
  group('colIndex', () {
    test('однобуквенные колонки', () {
      expect(colIndex('A1'), 0);
      expect(colIndex('B1'), 1);
      expect(colIndex('Z99'), 25);
    });

    test('двухбуквенные колонки', () {
      expect(colIndex('AA1'), 26);
      expect(colIndex('AB12'), 27);
      expect(colIndex('BA3'), 52);
    });

    test('строчные буквы приводятся к верхнему регистру', () {
      expect(colIndex('aa7'), 26);
    });
  });

  group('parseExcelDate', () {
    test('dd.mm.yyyy', () {
      expect(parseExcelDate('15.03.2026'), DateTime(2026, 3, 15));
      expect(parseExcelDate('01.01.2001'), DateTime(2001, 1, 1));
    });

    test('ISO', () {
      expect(parseExcelDate('2026-03-15'), DateTime(2026, 3, 15));
      expect(parseExcelDate('2026-03-15T10:30:00'),
          DateTime(2026, 3, 15, 10, 30));
    });

    test('excel-serial (дни от 1899-12-30)', () {
      // 46096 → 2026-03-15
      expect(parseExcelDate('46096'),
          DateTime(1899, 12, 30).add(const Duration(days: 46096)));
      expect(parseExcelDate('46096'), DateTime(2026, 3, 15));
    });

    test('serial вне диапазона (≤14000, ≥100000) не считается датой', () {
      expect(parseExcelDate('14000'), null);
      expect(parseExcelDate('100000'), null);
      expect(parseExcelDate('5'), null);
    });

    test('год ≤1900 в dd.mm.yyyy не принимается', () {
      expect(parseExcelDate('01.01.1899'), null);
    });

    test('мусор → null', () {
      expect(parseExcelDate('не дата'), null);
    });
  });

  group('readXlsx', () {
    test('sparse-строки раскладываются по адресам ячеек', () {
      final bytes = xlsxBytes(
          '<row r="1">${cell('A1', 'a')}${cell('C1', 'c')}</row>');
      final rows = readXlsx(bytes);
      expect(rows, [
        ['a', null, 'c'],
      ]);
    });

    test('shared strings (t="s")', () {
      final bytes = xlsxBytes(
        '<row r="1"><c r="A1" t="s"><v>1</v></c><c r="B1" t="s"><v>0</v></c></row>',
        sharedStringsXml: '<si><t>ноль</t></si><si><t>один</t></si>',
      );
      expect(readXlsx(bytes), [
        ['один', 'ноль'],
      ]);
    });
  });

  group('ExcelImportService', () {
    final svc = ExcelImportService();

    test('parseVehicles: строки с №, разбиение марки и модели', () {
      final bytes = xlsxBytes('''
<row r="1">${cell('A1', '№')}${cell('B1', 'Гаражный №')}</row>
<row r="2">${num_('A2', 1)}${cell('B2', '100011')}${cell('C2', 'КАМАЗ 43118-24')}${cell('D2', 'А123ВС 42')}</row>
<row r="3">${num_('A3', 2)}${cell('B3', '1059')}${cell('C3', 'ГАЗель')}</row>
<row r="4">${num_('A4', 1000)}${cell('B4', '9999')}${cell('C4', 'Не импортируется — счётчик >999')}</row>
<row r="5">${num_('A5', 3)}</row>
''');
      final vehicles = svc.parseVehicles(bytes);

      expect(vehicles.length, 2);
      expect(vehicles[0].invNumber, '100011');
      expect(vehicles[0].brand, 'КАМАЗ');
      expect(vehicles[0].model, '43118-24');
      expect(vehicles[0].govNumber, 'А123ВС 42');
      // Одно слово — только марка, модель пустая, госномера нет
      expect(vehicles[1].invNumber, '1059');
      expect(vehicles[1].brand, 'ГАЗель');
      expect(vehicles[1].model, '');
      expect(vehicles[1].govNumber, '');
    });

    test('parseDrivers: сбор ТС по табельному номеру, мед. срок', () {
      final bytes = xlsxBytes('''
<row r="1">${cell('A1', '№')}</row>
<row r="2">${num_('A2', 1)}${cell('B2', '4501')}${cell('C2', 'Иванов Иван Иванович')}${cell('D2', '99 XX 123456')}${cell('I2', '15.03.2024')}${num_('J2', 2)}${cell('K2', '100011')}</row>
<row r="3">${num_('A3', 2)}${cell('B3', '4501')}${cell('C3', 'Иванов Иван Иванович')}${cell('K3', '1059')}</row>
<row r="4">${num_('A4', 3)}${cell('B4', '4502')}${cell('C4', 'Петров')}</row>
''');
      final drivers = svc.parseDrivers(bytes);

      expect(drivers.length, 2);
      final ivanov = drivers.firstWhere((d) => d.tabNumber == '4501');
      expect(ivanov.lastName, 'Иванов');
      expect(ivanov.firstName, 'Иван');
      expect(ivanov.middleName, 'Иванович');
      expect(ivanov.licenseNumber, '99 XX 123456');
      // 15.03.2024 + 2 года
      expect(ivanov.medicalExpiry, DateTime(2026, 3, 15));
      // Оба ТС из двух строк, без дублей
      expect(ivanov.vehicleInvNumbers, ['100011', '1059']);

      final petrov = drivers.firstWhere((d) => d.tabNumber == '4502');
      expect(petrov.lastName, 'Петров');
      expect(petrov.firstName, '');
      expect(petrov.middleName, null);
      expect(petrov.medicalExpiry, null);
      expect(petrov.vehicleInvNumbers, isEmpty);
    });

    test('parseEngineHours: гаражные № >100000, часы округляются', () {
      final bytes = xlsxBytes('''
<row r="1">${num_('A1', 100011)}${num_('E1', '123.6')}</row>
<row r="2">${num_('A2', 99999)}${num_('E2', 50)}</row>
<row r="3">${num_('A3', 109002)}</row>
''');
      final hours = svc.parseEngineHours(bytes);

      expect(hours.length, 1);
      expect(hours[0].invNumber, '100011');
      expect(hours[0].hours, 124);
    });
  });
}
