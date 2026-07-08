import 'package:flutter/material.dart';

/// Телефон → мобильный UI (нижняя навигация, bottom-sheet пикеры и т.п.).
/// По shortestSide, поэтому ориентация не влияет: телефон в альбомной
/// ориентации остаётся телефоном.
bool isPhone(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide < 600;

/// Узкая текущая ширина — для решений внутри раскладки
/// (число колонок, Row vs Column и т.п.). Зависит от ориентации.
bool isCompactWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 600;
