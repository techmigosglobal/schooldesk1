import 'package:flutter/material.dart';

/// App-wide extension methods for common formatting and utility operations.
extension StringExtensions on String {
  String get capitalize =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
  String get titleCase => split(' ').map((w) => w.capitalize).join(' ');
  bool get isValidEmail => RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  ).hasMatch(this);
  bool get isValidPhone =>
      RegExp(r'^\+?[0-9]{10,15}$').hasMatch(replaceAll(' ', ''));
  String truncate(int maxLength) =>
      length > maxLength ? '${substring(0, maxLength)}...' : this;
}

extension DateTimeExtensions on DateTime {
  static const List<String> _months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String get formattedDate {
    final d = day.toString().padLeft(2, '0');
    final m = _months[month];
    return '$d $m $year';
  }

  String get formattedDateTime {
    final d = day.toString().padLeft(2, '0');
    final m = _months[month];
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final min = minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    return '$d $m $year, ${h.toString().padLeft(2, '0')}:$min $ampm';
  }

  String get formattedTime {
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final min = minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    return '${h.toString().padLeft(2, '0')}:$min $ampm';
  }

  String get isoDate {
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$year-$m-$d';
  }

  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isPast => isBefore(DateTime.now());
  bool get isFuture => isAfter(DateTime.now());
}

extension DoubleExtensions on double {
  String get currency => '₹${toStringAsFixed(2)}';
  String get currencyCompact {
    if (this >= 100000) return '₹${(this / 100000).toStringAsFixed(1)}L';
    if (this >= 1000) return '₹${(this / 1000).toStringAsFixed(1)}K';
    return '₹${toStringAsFixed(0)}';
  }

  String get percentage => '${toStringAsFixed(1)}%';
}

extension IntExtensions on int {
  String get currency => '₹$this';
  String get ordinal {
    if (this >= 11 && this <= 13) return '${this}th';
    switch (this % 10) {
      case 1:
        return '${this}st';
      case 2:
        return '${this}nd';
      case 3:
        return '${this}rd';
      default:
        return '${this}th';
    }
  }
}

extension ContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
  bool get isMobile => screenWidth < 600;
  bool get isTablet => screenWidth >= 600 && screenWidth < 1200;
  bool get isDesktop => screenWidth >= 1200;

  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void showErrorSnackBar(String message) =>
      showSnackBar(message, isError: true);
  void showSuccessSnackBar(String message) => showSnackBar(message);
}
