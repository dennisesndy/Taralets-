import 'package:flutter/services.dart';

/// Forces typed or pasted text to uppercase.
class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// Home header greeting.
String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good morning,';
  if (now.hour < 18) return 'Good afternoon,';
  return 'Good evening,';
}
