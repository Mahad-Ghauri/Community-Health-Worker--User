/// Error Handler Service - Provides user-friendly error messages
/// Used across all providers, services, and view models
class ErrorHandler {
  /// Convert technical error messages to user-friendly messages
  static String getUserFriendlyMessage(String error) {
    final errorLower = error.toLowerCase();

    // Authentication errors
    if (errorLower.contains('permission') ||
        errorLower.contains('unauthorized')) {
      return 'You do not have permission to perform this action. Please contact your administrator.';
    }

    if (errorLower.contains('not authenticated') ||
        errorLower.contains('user not authenticated')) {
      return 'Authentication error: Please log in again.';
    }

    if (errorLower.contains('invalid credentials') ||
        errorLower.contains('wrong password')) {
      return 'Invalid login credentials. Please check your email and password.';
    }

    // Network errors
    if (errorLower.contains('network') ||
        errorLower.contains('connection') ||
        errorLower.contains('internet')) {
      return 'Network error: Please check your internet connection and try again.';
    }

    if (errorLower.contains('timeout') || errorLower.contains('timed out')) {
      return 'Request timed out. Please try again.';
    }

    if (errorLower.contains('offline') || errorLower.contains('no internet')) {
      return 'You are offline. Please check your internet connection and try again.';
    }

    // Data errors
    if (errorLower.contains('not found') ||
        errorLower.contains('does not exist')) {
      return 'The requested information was not found. It may have been removed or you may not have access to it.';
    }

    if (errorLower.contains('already exists') ||
        errorLower.contains('duplicate')) {
      return 'This information already exists. Please check your data and try again.';
    }

    if (errorLower.contains('required') || errorLower.contains('missing')) {
      return 'Required information is missing. Please fill in all required fields.';
    }

    if (errorLower.contains('invalid') || errorLower.contains('malformed')) {
      return 'Invalid data format. Please check your input and try again.';
    }

    // GPS/Location errors
    if (errorLower.contains('gps') ||
        errorLower.contains('location') ||
        errorLower.contains('coordinates')) {
      return 'Location error: Please ensure GPS is enabled and location permissions are granted.';
    }

    if (errorLower.contains('permission denied') &&
        errorLower.contains('location')) {
      return 'Location permission denied. Please enable location access in your device settings.';
    }

    // File/Storage errors
    if (errorLower.contains('file') ||
        errorLower.contains('storage') ||
        errorLower.contains('upload')) {
      return 'File error: Please check your file and try again.';
    }

    if (errorLower.contains('size') && errorLower.contains('too large')) {
      return 'File is too large. Please choose a smaller file.';
    }

    // Database errors
    if (errorLower.contains('database') ||
        errorLower.contains('firestore') ||
        errorLower.contains('firebase')) {
      return 'Database error: Please try again. If the problem persists, contact support.';
    }

    if (errorLower.contains('quota') || errorLower.contains('limit')) {
      return 'Storage limit reached. Please contact your administrator.';
    }

    // Visit-specific errors
    if (errorLower.contains('2 hours') ||
        errorLower.contains('wait at least')) {
      return 'Cannot create visit: You must wait at least 2 hours between visits for the same patient. This prevents duplicate entries.';
    }

    if (errorLower.contains('recent visit already exists')) {
      return 'A recent visit already exists for this patient. Please wait before creating another visit.';
    }

    // Patient-specific errors
    if (errorLower.contains('patient not found')) {
      return 'Patient not found. Please check the patient ID and try again.';
    }

    if (errorLower.contains('patient already registered')) {
      return 'This patient is already registered in the system.';
    }

    // Family/Household errors
    if (errorLower.contains('household') || errorLower.contains('family')) {
      return 'Family information error: Please check the family details and try again.';
    }

    // Medication/Adherence errors
    if (errorLower.contains('medication') || errorLower.contains('adherence')) {
      return 'Medication tracking error: Please check the medication details and try again.';
    }

    // Generic fallback
    return 'An unexpected error occurred. Please try again or contact support if the problem persists.';
  }

  /// Get error category for UI styling
  static ErrorCategory getErrorCategory(String error) {
    final errorLower = error.toLowerCase();

    if (errorLower.contains('permission') ||
        errorLower.contains('unauthorized') ||
        errorLower.contains('not authenticated')) {
      return ErrorCategory.authentication;
    }

    if (errorLower.contains('network') ||
        errorLower.contains('connection') ||
        errorLower.contains('timeout') ||
        errorLower.contains('offline')) {
      return ErrorCategory.network;
    }

    if (errorLower.contains('gps') || errorLower.contains('location')) {
      return ErrorCategory.location;
    }

    if (errorLower.contains('file') ||
        errorLower.contains('storage') ||
        errorLower.contains('upload')) {
      return ErrorCategory.file;
    }

    if (errorLower.contains('database') ||
        errorLower.contains('firestore') ||
        errorLower.contains('firebase')) {
      return ErrorCategory.database;
    }

    return ErrorCategory.generic;
  }

  /// Get appropriate icon for error category
  static String getErrorIcon(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.authentication:
        return '🔐';
      case ErrorCategory.network:
        return '📶';
      case ErrorCategory.location:
        return '📍';
      case ErrorCategory.file:
        return '📁';
      case ErrorCategory.database:
        return '🗄️';
      case ErrorCategory.generic:
        return '⚠️';
    }
  }

  /// Get appropriate color for error category
  static int getErrorColor(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.authentication:
        return 0xFFE53E3E; // Red
      case ErrorCategory.network:
        return 0xFF3182CE; // Blue
      case ErrorCategory.location:
        return 0xFF38A169; // Green
      case ErrorCategory.file:
        return 0xFF805AD5; // Purple
      case ErrorCategory.database:
        return 0xFFD69E2E; // Yellow
      case ErrorCategory.generic:
        return 0xFF718096; // Gray
    }
  }
}

/// Error categories for UI styling
enum ErrorCategory {
  authentication,
  network,
  location,
  file,
  database,
  generic,
}
