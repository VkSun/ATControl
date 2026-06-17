import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/router.dart';
import 'utils/theme.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/notification_service.dart';
import 'services/autostart_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SharedPreferences.getInstance(); // кэшируем, чтобы провайдеры читали синхронно
  await initializeDateFormatting('ru', null);
  await NotificationService.init();
  await AutostartService.init();

  await Supabase.initialize(
    url: 'https://gmekcuwebewdhupywyal.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdtZWtjdXdlYmV3ZGh1cHl3eWFsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczOTU5NDMsImV4cCI6MjA5Mjk3MTk0M30.gqxIiHldZViI4f_sTrjuG3Bmr18jAZKfJNyLpO8l10s',
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
    final themeMode = ref.watch(themeModeProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final scale = ref.watch(scaleProvider);

    return MaterialApp.router(
      title: 'ATControl',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('ru'), Locale('en')],
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
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