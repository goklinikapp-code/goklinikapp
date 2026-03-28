import 'package:intl/intl.dart';

class FormatterConfig {
  static String _locale = 'en_US';
  static String _currency = 'USD';

  static String get locale => _locale;
  static String get currency => _currency;

  static void configure({required String locale, required String currency}) {
    _locale = locale;
    _currency = currency;
  }
}

String formatCurrency(num value) {
  final formatter = NumberFormat.simpleCurrency(
    locale: FormatterConfig.locale,
    name: FormatterConfig.currency,
  );
  return formatter.format(value);
}

String formatDate(DateTime date) {
  final formatter = DateFormat.yMd(FormatterConfig.locale);
  return formatter.format(date);
}

String formatDateTime(DateTime date) {
  final formatter = DateFormat.yMd(FormatterConfig.locale).add_Hm();
  return formatter.format(date);
}

String maskCpf(String raw) {
  final onlyDigits = raw.replaceAll(RegExp(r'\D'), '');
  if (onlyDigits.length <= 3) return onlyDigits;
  if (onlyDigits.length <= 6) return '${onlyDigits.substring(0, 3)}.${onlyDigits.substring(3)}';
  if (onlyDigits.length <= 9) {
    return '${onlyDigits.substring(0, 3)}.${onlyDigits.substring(3, 6)}.${onlyDigits.substring(6)}';
  }
  final limited = onlyDigits.substring(0, onlyDigits.length.clamp(0, 11));
  if (limited.length <= 9) return limited;
  return '${limited.substring(0, 3)}.${limited.substring(3, 6)}.${limited.substring(6, 9)}-${limited.substring(9)}';
}

String maskPhone(String raw) {
  final onlyDigits = raw.replaceAll(RegExp(r'\D'), '');
  if (onlyDigits.length <= 2) return '($onlyDigits';
  if (onlyDigits.length <= 7) return '(${onlyDigits.substring(0, 2)}) ${onlyDigits.substring(2)}';
  final limited = onlyDigits.substring(0, onlyDigits.length.clamp(0, 11));
  if (limited.length <= 10) {
    return '(${limited.substring(0, 2)}) ${limited.substring(2, 6)}-${limited.substring(6)}';
  }
  return '(${limited.substring(0, 2)}) ${limited.substring(2, 7)}-${limited.substring(7)}';
}
