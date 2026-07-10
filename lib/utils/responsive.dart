import 'package:flutter/material.dart';
import '../platform/app_platform.dart';

/// Телефон → мобильный UI (нижняя навигация, bottom-sheet пикеры,
/// full-screen диалоги и т.п.).
///
/// На Windows и Android раскладка закреплена за платформой и не зависит от
/// размера окна/экрана: на ПК окно можно сжать сколь угодно узко — оно не
/// должно «перескакивать» в мобильный UI, а на Android (включая планшеты)
/// наоборот должен быть только мобильный UI. На вебе платформенного сигнала
/// нет (заходят и с телефона, и с ПК) — там раскладка по-прежнему решается
/// физическим размером экрана (shortestSide), ориентация не влияет.
bool isPhone(BuildContext context) {
  if (AppPlatform.isAndroid) return true;
  if (AppPlatform.isWindows) return false;
  return MediaQuery.sizeOf(context).shortestSide < 600;
}

/// Узкая текущая ширина — для решений внутри раскладки
/// (число колонок, Row vs Column и т.п.). Зависит от ориентации.
bool isCompactWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 600;
