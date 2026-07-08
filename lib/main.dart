import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'utils/router.dart';
import 'utils/theme.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';

import 'platform/app_platform.dart';
import 'services/notification_service.dart';
import 'services/offline_queue.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppPlatform.window.init(); // prevent-close и трей (no-op вне Windows)

  await SharedPreferences.getInstance(); // кэшируем, чтобы провайдеры читали синхронно
  await initializeDateFormatting('ru', null);
  await NotificationService.init();
  await AppPlatform.autostart.init();

  // Очередь могла остаться с прошлого запуска — показываем её в бейдже сразу
  unawaited(OfflineQueue.instance.refreshCount());

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: ATControlApp(),
    ),
  );
}

class ATControlApp extends ConsumerWidget {
  const ATControlApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final resolvedTheme = ref.watch(resolvedThemeProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final scale = ref.watch(scaleProvider);

    return MaterialApp.router(
      title: 'ATControl',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('ru'), Locale('en')],
      theme: resolvedTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(fontSize),
            size: Size(mq.size.width / scale, mq.size.height / scale),
          ),
          child: child!,
        );
      },
    );
  }
}