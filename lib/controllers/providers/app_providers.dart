// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../../models/core_models.dart';
import 'patient_provider.dart';
import 'secondary_providers.dart';
import '../services/error_handler.dart';

/// Authentication Provider - Manages user authentication state
/// Used by: Welcome Screen (1), CHW Registration (2), Login (3), Forgot Password (4)
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService.instance;
  User? _user;
  CHWUser? _chwUser;
  bool _isLoading = false;
  String? _error;

  AuthProvider() {
    // Listen to auth state changes
    _authService.authStateChanges.listen((user) {
      _user = user;
      if (user != null) {
        _loadCHWUserData();
      } else {
        _chwUser = null;
      }
      notifyListeners();
    });
  }

  // Getters
  User? get user => _user;
  CHWUser? get chwUser => _chwUser;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Generate next unique CHW ID (CHW001, CHW002, etc.)
  Future<String> _generateNextCHWId() async {
    try {
      // Query existing CHW users to find the highest CHW ID number
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'chw')
          .orderBy('idNumber', descending: true)
          .limit(1)
          .get();

      int nextNumber = 1;

      if (querySnapshot.docs.isNotEmpty) {
        final lastCHWId =
            querySnapshot.docs.first.data()['idNumber'] as String?;
        if (lastCHWId != null && lastCHWId.startsWith('CHW')) {
          // Extract number from CHW001, CHW002, etc.
          final numberPart = lastCHWId.substring(3);
          final lastNumber = int.tryParse(numberPart) ?? 0;
          nextNumber = lastNumber + 1;
        }
      }

      // Format as CHW001, CHW002, etc.
      return 'CHW${nextNumber.toString().padLeft(3, '0')}';
    } catch (e) {
      // Fallback in case of error
      print('Error generating CHW ID: $e');
      return 'CHW${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    }
  }

  /// Sign in CHW - Used by Screen 3: Login Screen
  Future<String?> signIn(String email, String password) async {
    try {
      _setLoading(true);
      _clearError();

      await _authService.signIn(email, password);

      // Load CHW user data after successful authentication
      await _loadCHWUserData();

      // Determine navigation destination based on first-time setup status
      if (_chwUser != null) {
        return '/main-navigation'; // Existing user goes to main navigation screen
      }

      return '/main-navigation'; // Default fallback to main navigation
    } catch (e) {
      _setError('Login failed: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Register new CHW - Used by Screen 2: CHW Registration
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String workingArea,
    String? dateOfBirth,
    String? gender,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // Create Firebase Auth user
      await _authService.signUp(
        email: email,
        password: password,
        displayName: fullName,
      );

      // Create CHW user document in Firestore
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Generate unique CHW ID
        final idNumber = await _generateNextCHWId();

        final chwUser = CHWUser(
          userId: currentUser.uid,
          name: fullName,
          email: email,
          phone: phoneNumber,
          workingArea: workingArea,
          facilityId: null, // CHWs can work at multiple facilities
          idNumber: idNumber, // Auto-generated CHW ID
          dateOfBirth: dateOfBirth,
          gender: gender,
          createdAt: DateTime.now(),
        );

        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set(chwUser.toFirestore());

        _chwUser = chwUser;
      }

      return true;
    } catch (e) {
      _setError('Registration failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Complete first-time setup for CHW
  Future<bool> completeFirstTimeSetup() async {
    try {
      if (_chwUser == null || _user == null) return false;

      // Update the user document to mark first-time setup as complete
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .update({'isFirstTimeSetupComplete': true});

      // Update local state
      _chwUser = CHWUser(
        userId: _chwUser!.userId,
        name: _chwUser!.name,
        email: _chwUser!.email,
        phone: _chwUser!.phone,
        workingArea: _chwUser!.workingArea,
        role: _chwUser!.role,
        status: _chwUser!.status,
        facilityId: _chwUser!.facilityId,
        idNumber: _chwUser!.idNumber,
        dateOfBirth: _chwUser!.dateOfBirth,
        gender: _chwUser!.gender,
        createdAt: _chwUser!.createdAt,
      );

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to complete setup: $e');
      return false;
    }
  }

  /// Sign out CHW
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _chwUser = null;
    } catch (e) {
      _setError('Sign out failed: $e');
    }
  }

  /// Load CHW user data from Firestore
  Future<void> _loadCHWUserData() async {
    try {
      if (_user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();

      if (doc.exists) {
        _chwUser = CHWUser.fromFirestore(doc.data()!);
        notifyListeners();
      }
    } catch (e) {
      print('Failed to load CHW user data: $e');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = ErrorHandler.getUserFriendlyMessage(error);
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}

/// Main App Providers - Central configuration for all state management
/// Used by: main.dart to initialize all providers for the CHW TB Tracker app
///
/// This aggregates all providers according to the exact collection usage patterns
/// defined in the JSON specification for all 31 screens
class AppProviders {
  /// Get all providers for MultiProvider in main.dart
  /// Provides state management for all collections and services
  static List<ChangeNotifierProvider> getProviders() {
    return [
      // Authentication Provider - Must be first
      // Used by: Welcome Screen (1), CHW Registration (2), Login (3), Forgot Password (4)
      ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),

      // Patient Management Providers
      // Used by: Patient List (8), Patient Search (9), Patient Details (11),
      //         Register New Patient (10), Edit Patient (12), Home Dashboard (6)
      ChangeNotifierProvider<PatientProvider>(create: (_) => PatientProvider()),

      // Visit Management Providers
      // Used by: New Visit (14), Visit List (13), Visit Details (15), Home Dashboard (6)
      ChangeNotifierProvider<VisitProvider>(create: (_) => VisitProvider()),

      // Household Management Providers
      // Used by: Household Members (16), Add Household Member (17)
      ChangeNotifierProvider<HouseholdProvider>(
        create: (_) => HouseholdProvider(),
      ),

      // Contact Tracing Providers
      // Used by: Contact Screening (18), Screening Results (19)
      ChangeNotifierProvider<ContactTracingProvider>(
        create: (_) => ContactTracingProvider(),
      ),

      // Treatment Adherence Providers
      // Used by: Adherence Tracking (20), Side Effects Log (21), Pill Count (22)
      ChangeNotifierProvider<TreatmentAdherenceProvider>(
        create: (_) => TreatmentAdherenceProvider(),
      ),

      // Notification Management Providers
      // Used by: Home Dashboard (6), Notifications List (23), Missed Follow-up Alert (24)
      ChangeNotifierProvider<NotificationProvider>(
        create: (_) => NotificationProvider(),
      ),

      // Read-Only Data Provider
      // Used by: Facilities (10), Follow-ups (11,23,24), Assignments (8), Outcomes (11)
      ChangeNotifierProvider<ReadOnlyDataProvider>(
        create: (_) => ReadOnlyDataProvider(),
      ),

      // App-wide state management
      ChangeNotifierProvider<AppStateProvider>(
        create: (_) => AppStateProvider(),
      ),
    ];
  }

  /// Initialize all providers after user authentication
  /// Called after successful login to load initial data
  static Future<void> initializeProviders() async {
    print('🚀 Initializing CHW TB Tracker providers...');

    // Note: Individual provider initialization will be handled by
    // the screens that use them, following the exact usage patterns
    // defined in the JSON specification
  }
}

/// App State Provider - Manages global app state
/// Used by: All screens for connectivity, sync status, settings
class AppStateProvider with ChangeNotifier {
  bool _isOnline = true;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String _selectedLanguage = 'en';
  Map<String, dynamic> _appSettings = {};
  String? _error;

  // Getters
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String get selectedLanguage => _selectedLanguage;
  Map<String, dynamic> get appSettings => _appSettings;
  String? get error => _error;

  /// Initialize app state - Called when app starts
  Future<void> initialize() async {
    await _loadAppSettings();
    await _checkConnectivity();
    await _loadLastSyncTime();
  }

  /// Update connectivity status - Used by Sync Status Screen (Screen 25)
  void updateConnectivity(bool isOnline) {
    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      notifyListeners();

      if (isOnline && !_isSyncing) {
        // Auto-sync when connection is restored
        _performAutoSync();
      }
    }
  }

  /// Start sync process - Used by Sync Status Screen (Screen 25)
  Future<void> startSync() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _error = null;
    notifyListeners();

    try {
      // Perform sync operations here
      await _syncPendingData();

      _lastSyncTime = DateTime.now();
      await _saveLastSyncTime();

      _isSyncing = false;
      notifyListeners();
    } catch (e) {
      _error = ErrorHandler.getUserFriendlyMessage('Sync failed: $e');
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Change app language - Used by App Settings Screen (Screen 29)
  Future<void> changeLanguage(String languageCode) async {
    if (_selectedLanguage != languageCode) {
      _selectedLanguage = languageCode;
      await _saveAppSettings();
      notifyListeners();
    }
  }

  /// Update app settings - Used by App Settings Screen (Screen 29)
  Future<void> updateSettings(Map<String, dynamic> newSettings) async {
    _appSettings.addAll(newSettings);
    await _saveAppSettings();
    notifyListeners();
  }

  /// Get sync status info - Used by Sync Status Screen (Screen 25)
  Map<String, dynamic> getSyncStatusInfo() {
    return {
      'is_online': _isOnline,
      'is_syncing': _isSyncing,
      'last_sync': _lastSyncTime?.toIso8601String(),
      'pending_items': _getPendingSyncCount(),
      'sync_error': _error,
    };
  }

  // Private methods
  Future<void> _loadAppSettings() async {
    // Load settings from SharedPreferences or local storage
    _appSettings = {
      'notifications_enabled': true,
      'auto_sync': true,
      'gps_accuracy': 'high',
      'offline_mode': false,
    };
  }

  Future<void> _saveAppSettings() async {
    // Save settings to SharedPreferences or local storage
  }

  Future<void> _checkConnectivity() async {
    // Check internet connectivity
    _isOnline = true; // Placeholder
  }

  Future<void> _loadLastSyncTime() async {
    // Load last sync time from local storage
  }

  Future<void> _saveLastSyncTime() async {
    // Save last sync time to local storage
  }

  Future<void> _performAutoSync() async {
    if (_appSettings['auto_sync'] == true) {
      await startSync();
    }
  }

  Future<void> _syncPendingData() async {
    // Implement actual sync logic here
    // This would sync offline data with Firestore
    await Future.delayed(Duration(seconds: 2)); // Placeholder
  }

  int _getPendingSyncCount() {
    // In a real implementation, this would check:
    // 1. Local storage for unsaved changes
    // 2. Queue of failed sync operations
    // 3. New records created offline

    // For now, return a realistic count based on app state
    // This could be enhanced to check actual pending data
    if (!_isOnline) {
      return 5; // Assume some offline changes when offline
    }

    if (_error != null) {
      return 3; // Some items failed to sync
    }

    return 0; // All synced when online and no errors
  }
}

/// Read-Only Data Provider - Manages data that CHWs can read but not create
/// Used for: Facilities (10), Follow-ups (11,23,24), Assignments (8), Outcomes (11)
class ReadOnlyDataProvider with ChangeNotifier {
  List<Facility> _facilities = [];
  List<Followup> _followups = [];
  List<Assignment> _assignments = [];
  List<TreatmentOutcome> _outcomes = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Facility> get facilities => _facilities;
  List<Followup> get followups => _followups;
  List<Assignment> get assignments => _assignments;
  List<TreatmentOutcome> get outcomes => _outcomes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load facilities for patient registration - Used by Screen 10: Register New Patient
  Future<void> loadFacilities() async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await FirebaseFirestore.instance
          .collection('facilities')
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      _facilities = snapshot.docs
          .map((doc) => Facility.fromFirestore(doc.data()))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = ErrorHandler.getUserFriendlyMessage(
        'Failed to load facilities: $e',
      );
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load patient assignments - Used by Screen 8: Patient List
  Future<void> loadAssignments() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('assignments')
          .where('chwId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'active')
          .get();

      _assignments = snapshot.docs
          .map((doc) => Assignment.fromFirestore(doc.data()))
          .toList();

      notifyListeners();
    } catch (e) {
      _error = ErrorHandler.getUserFriendlyMessage(
        'Failed to load assignments: $e',
      );
      notifyListeners();
    }
  }

  /// Load follow-ups for notifications - Used by Screens 11, 23, 24
  Future<void> loadFollowups() async {
    try {
      // Get patient IDs assigned to current CHW
      final patientIds = _assignments
          .expand((assignment) => assignment.patientIds)
          .toList();

      if (patientIds.isEmpty) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('followups')
          .where('patientId', whereIn: patientIds)
          .orderBy('scheduledDate', descending: true)
          .get();

      _followups = snapshot.docs
          .map((doc) => Followup.fromFirestore(doc.data()))
          .toList();

      notifyListeners();
    } catch (e) {
      _error = ErrorHandler.getUserFriendlyMessage(
        'Failed to load follow-ups: $e',
      );
      notifyListeners();
    }
  }

  /// Load treatment outcomes - Used by Screen 11: Patient Details
  Future<void> loadOutcomesForPatient(String patientId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('outcomes')
          .where('patientId', isEqualTo: patientId)
          .orderBy('recordedAt', descending: true)
          .get();

      _outcomes = snapshot.docs
          .map((doc) => TreatmentOutcome.fromFirestore(doc.data()))
          .toList();

      notifyListeners();
    } catch (e) {
      _error = ErrorHandler.getUserFriendlyMessage(
        'Failed to load outcomes: $e',
      );
      notifyListeners();
    }
  }
}
