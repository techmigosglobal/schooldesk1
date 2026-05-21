/// Input validators used across all form screens.
class AppValidators {
  AppValidators._();

  static String? required(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required.';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required.';
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    if (value.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required.';
    }
    final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
    if (!phoneRegex.hasMatch(value.replaceAll(' ', ''))) {
      return 'Enter a valid phone number.';
    }
    return null;
  }

  static String? minLength(
    String? value,
    int min, {
    String fieldName = 'This field',
  }) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required.';
    if (value.trim().length < min) {
      return '$fieldName must be at least $min characters.';
    }
    return null;
  }

  static String? maxLength(
    String? value,
    int max, {
    String fieldName = 'This field',
  }) {
    if (value != null && value.trim().length > max) {
      return '$fieldName must not exceed $max characters.';
    }
    return null;
  }

  static String? numeric(String? value, {String fieldName = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required.';
    if (double.tryParse(value.trim()) == null) {
      return '$fieldName must be a valid number.';
    }
    return null;
  }

  static String? positiveNumber(
    String? value, {
    String fieldName = 'This field',
  }) {
    final numError = numeric(value, fieldName: fieldName);
    if (numError != null) return numError;
    if (double.parse(value!.trim()) <= 0) {
      return '$fieldName must be greater than zero.';
    }
    return null;
  }

  static String? rollNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Roll number is required.';
    }
    if (value.trim().length > 10) {
      return 'Roll number must not exceed 10 characters.';
    }
    return null;
  }

  static String? admissionNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Admission number is required.';
    }
    return null;
  }
}
