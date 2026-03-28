import 'dart:developer' as developer;

class AppLogger {
  static void info(String message) {
    developer.log(message, name: 'GoKlinik');
  }

  static void error(String message, Object error, StackTrace stackTrace) {
    developer.log(message, name: 'GoKlinik', error: error, stackTrace: stackTrace);
  }
}
