// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/core_models.dart';
import '../services/audit_service.dart';
import '../services/gps_service.dart';

/// Household Provider - Manages household and family member state
/// Used by: Household Members (16), Add Household Member (17)
class HouseholdProvider with ChangeNotifier {
  List<Household> _households = [];
  Household? _selectedHousehold;
  bool _isLoading = false;
  String? _error;

  List<Household> get households => _households;
  Household? get selectedHousehold => _selectedHousehold;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load households for a patient - Used by Screen 16: Household Members
  Future<void> loadPatientHousehold(String patientId) async {
    try {
      print('🏠 HouseholdProvider: Loading household for patient: $patientId');
      _setLoading(true);
      _clearError();

      // Clear existing data first
      _households.clear();
      _selectedHousehold = null;
      print('🏠 HouseholdProvider: Cleared existing household data');
      notifyListeners();

      final snapshot = await FirebaseFirestore.instance
          .collection('households')
          .where('patientId', isEqualTo: patientId)
          .get();

      print(
        '🏠 HouseholdProvider: Firestore query returned ${snapshot.docs.length} documents',
      );

      _households = snapshot.docs
          .map((doc) => Household.fromFirestore(doc.data()))
          .toList();

      _selectedHousehold = _households.isNotEmpty ? _households.first : null;

      if (_selectedHousehold != null) {
        print(
          '🏠 HouseholdProvider: Selected household ID: ${_selectedHousehold!.householdId}',
        );
        print(
          '🏠 HouseholdProvider: Household patient ID: ${_selectedHousehold!.patientId}',
        );
        print(
          '🏠 HouseholdProvider: Household has ${_selectedHousehold!.members.length} members',
        );
        for (int i = 0; i < _selectedHousehold!.members.length; i++) {
          final member = _selectedHousehold!.members[i];
          print(
            '🏠 HouseholdProvider: Member $i: ${member.name} (${member.relationship})',
          );
        }
      } else {
        print(
          '🏠 HouseholdProvider: No household found for patient $patientId',
        );
      }

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      print('🏠 HouseholdProvider ERROR: Failed to load household: $e');
      _setError('Failed to load household: $e');
      _setLoading(false);
    }
  }

  /// Add household member - Used by Screen 17: Add Household Member
  Future<bool> addHouseholdMember({
    required String patientId,
    required String name,
    required int age,
    required String gender,
    required String relationship,
    String? phone,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // Find existing household or create new one
      Household? household = _households.isNotEmpty ? _households.first : null;

      final newMember = HouseholdMember(
        name: name,
        age: age,
        gender: gender,
        relationship: relationship,
        phone: phone,
      );

      if (household == null) {
        // Create new household
        final householdId = FirebaseFirestore.instance
            .collection('households')
            .doc()
            .id;
        household = Household(
          householdId: householdId,
          patientId: patientId,
          address: '', // Will be filled from patient data
          totalMembers: 1,
          screenedMembers: 0,
          members: [newMember],
          createdAt: DateTime.now(),
        );

        await FirebaseFirestore.instance
            .collection('households')
            .doc(householdId)
            .set(household.toFirestore());
      } else {
        // Add member to existing household
        final updatedMembers = [...household.members, newMember];
        final updatedHousehold = Household(
          householdId: household.householdId,
          patientId: household.patientId,
          address: household.address,
          totalMembers: updatedMembers.length,
          screenedMembers: household.screenedMembers,
          members: updatedMembers,
          createdAt: household.createdAt,
        );

        await FirebaseFirestore.instance
            .collection('households')
            .doc(household.householdId)
            .update(updatedHousehold.toFirestore());
      }

      // Log action
      await AuditService().logHouseholdMemberAdded(household.householdId, {
        'name': name,
        'relationship': relationship,
        'age': age,
      });

      // Refresh data
      await loadPatientHousehold(patientId);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to add household member: $e');
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  /// Clear household data - useful when switching patients
  void clearHouseholdData() {
    print('🏠 HouseholdProvider: Clearing household data');
    _households.clear();
    _selectedHousehold = null;
    _error = null;
    notifyListeners();
    print(
      '🏠 HouseholdProvider: Household data cleared and listeners notified',
    );
  }
}

/// Contact Tracing Provider - Manages contact screening state
/// Used by: Contact Screening (18), Screening Results (19)
class ContactTracingProvider with ChangeNotifier {
  List<ContactTracing> _contacts = [];
  ContactTracing? _selectedContact;
  bool _isLoading = false;
  String? _error;

  List<ContactTracing> get contacts => _contacts;
  ContactTracing? get selectedContact => _selectedContact;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load contacts for a household - Used by Screen 18: Contact Screening
  Future<void> loadHouseholdContacts(String householdId) async {
    try {
      _setLoading(true);
      _clearError();

      final snapshot = await FirebaseFirestore.instance
          .collection('contactTracing')
          .where('householdId', isEqualTo: householdId)
          .orderBy('screeningDate', descending: true)
          .get();

      _contacts = snapshot.docs
          .map((doc) => ContactTracing.fromFirestore(doc.data()))
          .toList();

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load contacts: $e');
      _setLoading(false);
    }
  }

  /// Screen contact for TB - Used by Screen 18: Contact Screening
  /// Ensures the stored householdId exactly matches an existing Household document.
  Future<String?> screenContact({
    required String householdId,
    required String indexPatientId,
    required String contactName,
    required String relationship,
    required int age,
    required String gender,
    required List<String> symptoms,
    required String notes,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final firestore = FirebaseFirestore.instance;
      final householdsCol = firestore.collection('households');

      // Resolve and validate the correct householdId to store
      String resolvedHouseholdId = householdId;
      try {
        // 1) Check if the provided householdId actually exists
        final providedDoc = await householdsCol.doc(householdId).get();
        if (!providedDoc.exists) {
          // 2) Fallback: find household by index patient
          final byPatient = await householdsCol
              .where('patientId', isEqualTo: indexPatientId)
              .limit(1)
              .get();
          if (byPatient.docs.isEmpty) {
            throw Exception(
              'No household found for index patient: $indexPatientId',
            );
          }
          // Prefer the field value, but doc.id is the source of truth
          final doc = byPatient.docs.first;
          resolvedHouseholdId =
              (doc.data()['householdId'] as String?) ?? doc.id;
        }
      } catch (e) {
        // If resolution fails for any reason, bubble up a clear error
        throw Exception('Failed to resolve householdId: $e');
      }

      final contactId = firestore.collection('contactTracing').doc().id;

      // Get GPS location for screening (optional, used for audit trail)
      try {
        await GPSService().getCurrentLocation();
      } catch (e) {
        // Continue without GPS if it fails
      }

      final contact = ContactTracing(
        contactId: contactId,
        householdId: resolvedHouseholdId,
        indexPatientId: indexPatientId,
        contactName: contactName,
        relationship: relationship,
        age: age,
        gender: gender,
        screeningDate: DateTime.now(),
        screenedBy: currentUser.uid,
        symptoms: symptoms,
        testResult: 'pending',
        referralNeeded: symptoms.isNotEmpty,
        notes: notes,
      );

      await firestore
          .collection('contactTracing')
          .doc(contactId)
          .set(contact.toFirestore());

      // Log action
      await AuditService().logContactScreening(contactId, {
        'contactName': contactName,
        'symptoms': symptoms,
        'testResult': 'pending',
        'referralNeeded': symptoms.isNotEmpty,
        'householdId': resolvedHouseholdId,
        'indexPatientId': indexPatientId,
      });

      // Refresh data with the resolved household id
      await loadHouseholdContacts(resolvedHouseholdId);

      _setLoading(false);
      return contactId;
    } catch (e) {
      _setError('Failed to screen contact: $e');
      _setLoading(false);
      return null;
    }
  }

  /// Update screening results - Used by Screen 19: Screening Results
  Future<bool> updateScreeningResults({
    required String contactId,
    required String testResult,
    required bool referralNeeded,
    String? notes,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      await FirebaseFirestore.instance
          .collection('contactTracing')
          .doc(contactId)
          .update({
            'testResult': testResult,
            'referralNeeded': referralNeeded,
            'notes': notes ?? '',
            'updatedAt': Timestamp.now(),
          });

      // Refresh selected contact
      if (_selectedContact?.contactId == contactId) {
        await selectContact(contactId);
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to update results: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Select contact for details
  Future<void> selectContact(String contactId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('contactTracing')
          .doc(contactId)
          .get();

      if (doc.exists) {
        _selectedContact = ContactTracing.fromFirestore(doc.data()!);
        notifyListeners();
      }
    } catch (e) {
      _setError('Failed to load contact details: $e');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}

/// Treatment Adherence Provider - Manages adherence tracking state
/// Used by: Adherence Tracking (20), Side Effects Log (21), Pill Count (22)
class TreatmentAdherenceProvider with ChangeNotifier {
  List<TreatmentAdherence> _adherenceRecords = [];
  TreatmentAdherence? _selectedRecord;
  Map<String, dynamic> _adherenceStats = {};
  bool _isLoading = false;
  String? _error;

  List<TreatmentAdherence> get adherenceRecords => _adherenceRecords;
  TreatmentAdherence? get selectedRecord => _selectedRecord;
  Map<String, dynamic> get adherenceStats => _adherenceStats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load adherence records for patient - Used by Screen 20: Adherence Tracking
  Future<void> loadPatientAdherence(String patientId) async {
    try {
      _setLoading(true);
      _clearError();

      final snapshot = await FirebaseFirestore.instance
          .collection('treatmentAdherence')
          .where('patientId', isEqualTo: patientId)
          .orderBy('date', descending: true)
          .get();

      _adherenceRecords = snapshot.docs
          .map((doc) => TreatmentAdherence.fromFirestore(doc.data()))
          .toList();

      // Calculate adherence statistics
      _calculateAdherenceStats();

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load adherence records: $e');
      _setLoading(false);
    }
  }

  /// Record adherence - Used by Screen 20: Adherence Tracking
  Future<String?> recordAdherence({
    required String patientId,
    String? visitId,
    required Map<String, String> dosesToday,
    required List<String> sideEffects,
    required Map<String, int> pillsRemaining,
    required bool counselingGiven,
    required String notes,
    DateTime? recordDate, // Optional custom date
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final adherenceId = FirebaseFirestore.instance
          .collection('treatmentAdherence')
          .doc()
          .id;

      // Calculate adherence score based on doses taken
      final totalDoses = dosesToday.length;
      final takenDoses = dosesToday.values
          .where((dose) => dose == 'taken')
          .length;
      final adherenceScore = totalDoses > 0
          ? (takenDoses / totalDoses) * 100
          : 0.0;

      final adherence = TreatmentAdherence(
        adherenceId: adherenceId,
        patientId: patientId,
        visitId: visitId,
        date: recordDate ?? DateTime.now(), // Use custom date or current date
        reportedBy: currentUser.uid,
        dosesToday: dosesToday,
        sideEffects: sideEffects,
        pillsRemaining: pillsRemaining,
        adherenceScore: adherenceScore,
        counselingGiven: counselingGiven,
        notes: notes,
      );

      await FirebaseFirestore.instance
          .collection('treatmentAdherence')
          .doc(adherenceId)
          .set(adherence.toFirestore());

      // Log action
      await AuditService().logAdherenceTracking(adherenceId, {
        'patientId': patientId,
        'dosesToday': dosesToday,
        'sideEffects': sideEffects,
        'adherenceScore': adherenceScore,
        'counselingGiven': counselingGiven,
      });

      // Refresh data
      await loadPatientAdherence(patientId);

      _setLoading(false);
      return adherenceId;
    } catch (e) {
      _setError('Failed to record adherence: $e');
      _setLoading(false);
      return null;
    }
  }

  /// Calculate adherence statistics
  void _calculateAdherenceStats() {
    if (_adherenceRecords.isEmpty) {
      _adherenceStats = {
        'overall_score': 0.0,
        'weekly_score': 0.0,
        'total_records': 0,
        'side_effects_reported': 0,
        'counseling_sessions': 0,
      };
      return;
    }

    final totalRecords = _adherenceRecords.length;
    final overallScore =
        _adherenceRecords.map((r) => r.adherenceScore).reduce((a, b) => a + b) /
        totalRecords;

    // Weekly score (last 7 days)
    final weekAgo = DateTime.now().subtract(Duration(days: 7));
    final weeklyRecords = _adherenceRecords
        .where((r) => r.date.isAfter(weekAgo))
        .toList();
    final weeklyScore = weeklyRecords.isEmpty
        ? 0.0
        : weeklyRecords.map((r) => r.adherenceScore).reduce((a, b) => a + b) /
              weeklyRecords.length;

    final sideEffectsReported = _adherenceRecords
        .where((r) => r.sideEffects.isNotEmpty)
        .length;

    final counselingSessions = _adherenceRecords
        .where((r) => r.counselingGiven)
        .length;

    _adherenceStats = {
      'overall_score': overallScore,
      'weekly_score': weeklyScore,
      'total_records': totalRecords,
      'side_effects_reported': sideEffectsReported,
      'counseling_sessions': counselingSessions,
    };
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}

/// Notification Provider - Manages notifications and alerts
/// Used by: Home Dashboard (6), Notifications List (23), Missed Follow-up Alert (24)
class NotificationProvider with ChangeNotifier {
  List<CHWNotification> _notifications = [];
  CHWNotification? _selectedNotification;
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;

  List<CHWNotification> get notifications => _notifications;
  CHWNotification? get selectedNotification => _selectedNotification;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load notifications for current CHW - Used by Screen 23: Notifications List
  Future<void> loadNotifications() async {
    try {
      _setLoading(true);
      _clearError();

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('sentAt', descending: true)
          .get();

      _notifications = snapshot.docs
          .map((doc) => CHWNotification.fromFirestore(doc.data()))
          .toList();

      _unreadCount = _notifications.where((n) => n.status == 'unread').length;

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load notifications: $e');
      _setLoading(false);
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'status': 'read', 'readAt': Timestamp.now()});

      // Update local state
      final index = _notifications.indexWhere(
        (n) => n.notificationId == notificationId,
      );
      if (index != -1) {
        _unreadCount = _notifications.where((n) => n.status == 'unread').length;
        notifyListeners();
      }

      // Refresh notifications
      await loadNotifications();
    } catch (e) {
      _setError('Failed to mark notification as read: $e');
    }
  }

  /// Get notifications for dashboard badge - Used by Screen 6: Home Dashboard
  int getUnreadCount() => _unreadCount;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
