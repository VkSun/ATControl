import 'package:supabase_flutter/supabase_flutter.dart';

import '../platform/app_platform.dart';
import '../utils/date_utils.dart';
import '../utils/logger.dart';

const _log = Logger('NotificationService');

/// Общая логика уведомлений об истечении сроков: запрос данных и подсчёт
/// порогов 7/14/30 дней. Платформенный только показ — AppPlatform.notifications.
class NotificationService {
  static bool _initialized = false;
  static bool _checked = false;

  static Future<void> init() async {
    if (_initialized) return;
    await AppPlatform.notifications.init();
    _initialized = true;
  }

  static Future<void> checkAndNotify({
    required bool notify7,
    required bool notify14,
    required bool notify30,
  }) async {
    if (_checked) return;
    _checked = true;
    if (!_initialized) return;
    if (!notify7 && !notify14 && !notify30) return;

    try {
      final supabase = Supabase.instance.client;
      if (supabase.auth.currentUser == null) return;

      final cutoff = toDateString(DateTime.now().add(const Duration(days: 30)));

      final List<Map<String, dynamic>> vehicles = await supabase
          .from('vehicles')
          .select(
              'inspection_date, insurance_date, special_permit_date, '
              'to_date, to_period_months, equipment_to_date, equipment_to_period_months')
          .or(
              'inspection_date.lte.$cutoff,insurance_date.lte.$cutoff,'
              'special_permit_date.lte.$cutoff,to_date.not.is.null,equipment_to_date.not.is.null');

      final List<Map<String, dynamic>> drivers = await supabase
          .from('drivers')
          .select('license_expiry, medical_expiry')
          .or('license_expiry.lte.$cutoff,medical_expiry.lte.$cutoff');

      int count7 = 0, count14 = 0, count30 = 0;

      void check(String? raw) {
        if (raw == null) return;
        final date = DateTime.tryParse(raw);
        if (date == null) return;
        final days = daysUntil(date);
        if (days < 0 || (days <= 7 && notify7)) {
          count7++;
        } else if (days <= 14 && notify14) {
          count14++;
        } else if (days <= 30 && notify30) {
          count30++;
        }
      }

      for (final v in vehicles) {
        check(v['inspection_date'] as String?);
        check(v['insurance_date'] as String?);
        check(v['special_permit_date'] as String?);
        if (v['to_date'] != null && v['to_period_months'] != null) {
          final d = DateTime.parse(v['to_date'] as String);
          final months = v['to_period_months'] as int;
          check(toDateString(DateTime(d.year, d.month + months, d.day)));
        }
        if (v['equipment_to_date'] != null && v['equipment_to_period_months'] != null) {
          final d = DateTime.parse(v['equipment_to_date'] as String);
          final months = v['equipment_to_period_months'] as int;
          check(toDateString(DateTime(d.year, d.month + months, d.day)));
        }
      }
      for (final d in drivers) {
        check(d['license_expiry'] as String?);
        check(d['medical_expiry'] as String?);
      }

      final total = count7 + count14 + count30;
      if (total == 0) return;

      final parts = <String>[];
      if (count7 > 0) parts.add('Срочно: $count7');
      if (count14 > 0) parts.add('14 дней: $count14');
      if (count30 > 0) parts.add('30 дней: $count30');

      await AppPlatform.notifications.show(
        title: 'ATControl — истекающих документов: $total',
        body: parts.join(' • '),
      );
    } catch (e, s) {
      _log.warning('checkAndNotify failed', e, s);
    }
  }

  static void resetCheckFlag() => _checked = false;
}
