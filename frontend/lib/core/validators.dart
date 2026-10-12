/// Form validators. Rules match the backend constraints (8+ char passwords).
class Validators {
  Validators._();

  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty || !_emailRegex.hasMatch(v)) {
      return 'Invalid email address';
    }
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  static String? Function(String?) confirmPassword(
    String Function() original, {
    String requiredMessage = 'Password confirmation is required',
  }) {
    return (String? value) {
      final v = value ?? '';
      if (v.isEmpty) return requiredMessage;
      if (v != original()) return "The passwords don't match";
      return null;
    };
  }

  static String? required(String? value, {String message = 'Required'}) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  static String? maxLength(String? value, int max) {
    if (value != null && value.length > max) {
      return 'Must be at most $max characters';
    }
    return null;
  }
}
