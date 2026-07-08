import 'dart:developer' as dev;

class Logger {
  final String name;
  const Logger(this.name);

  void warning(String message, [Object? error, StackTrace? stack]) =>
      dev.log(message, name: name, error: error, stackTrace: stack, level: 900);

  void error(String message, [Object? error, StackTrace? stack]) =>
      dev.log(message, name: name, error: error, stackTrace: stack, level: 1000);
}
