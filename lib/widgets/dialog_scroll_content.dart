import 'package:flutter/material.dart';

/// Максимальная высота контента диалога: 90% высоты экрана за вычетом
/// клавиатуры. Dialog сдвигается на viewInsets, поэтому без вычета
/// ограничение в 90% полной высоты выталкивало бы кнопки за экран.
double dialogMaxHeight(BuildContext context) {
  final media = MediaQuery.of(context);
  return (media.size.height - media.viewInsets.bottom) * 0.9;
}

/// Общая схема контента AlertDialog: высота ограничена [dialogMaxHeight],
/// контент прокручивается, а ряд кнопок (actions) остаётся закреплённым
/// вне прокрутки и не перекрывает контент.
class DialogScrollContent extends StatelessWidget {
  final Widget child;
  final double? width;

  const DialogScrollContent({super.key, this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: dialogMaxHeight(context)),
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(
          // Отступ сверху: floating-подпись верхнего поля выходит за его
          // рамку и иначе обрезается краем области прокрутки.
          padding: const EdgeInsets.only(top: 8),
          child: child,
        ),
      ),
    );
  }
}
