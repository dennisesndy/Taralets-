import 'package:flutter/material.dart';
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

const List<String> _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const List<String> _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "Saturday, August 29, 2026"
String formatLongDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}, ${d.year}';

/// "Aug 29, 2026"
String formatShortDate(DateTime d) =>
    '${_months[d.month - 1].substring(0, 3)} ${d.day}, ${d.year}';

/// "August 29, 2026" (date field value)
String formatInputDate(DateTime d) =>
    '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// "2:30 PM"
String formatTimeOfDay(TimeOfDay t) {
  final ap = t.hour >= 12 ? 'PM' : 'AM';
  final hr = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
  return '$hr:${t.minute.toString().padLeft(2, '0')} $ap';
}

TimeOfDay parseTimeOfDay(String timeString, {TimeOfDay? fallback}) {
  final cleaned = timeString.trim();
  final parts = cleaned.split(':');
  if (parts.length >= 2) {
    int hour = int.tryParse(parts[0]) ?? 0;
    int minute = int.tryParse(parts[1].split(' ')[0]) ?? 0;
    if (cleaned.toUpperCase().contains('PM') && hour < 12) {
      hour += 12;
    } else if (cleaned.toUpperCase().contains('AM') && hour == 12) {
      hour = 0;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }
  return fallback ?? const TimeOfDay(hour: 0, minute: 0);
}

String formatMinutes(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (remainingMinutes == 0) return '${hours}h';
  return '${hours}h ${remainingMinutes}m';
}
