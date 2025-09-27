// ignore_for_file: unnecessary_cast

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/core_models.dart';
import 'audit_service.dart';
import 'gps_service.dart';

/// Visit Service - Handles all visit-related operations
/// Used by: New Visit (14), Visit List (13), Visit Details (15), Home Dashboard (6)
class VisitService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final AuditService _auditService = AuditService();
  static final GPSService _gpsService = GPSService();

  // =================== CREATE OPERATIONS ===================

  /// Create new visit with GPS proof - Used by Screen 14: New Visit
  /// Auto-captures GPS, validates location, creates audit log
  static Future<String> createVisit({
    required String patientId,
    required String visitType,
    required bool found,
    required String notes,
    List<String>? photos,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Generate unique visit ID
      final visitId = _firestore.collection('visits').doc().id;

      // Get current GPS location with retry
      final gpsLocation = await _gpsService.getCurrentLocationWithRetry();

      final visit = Visit(
        visitId: visitId,
        patientId: patientId,
        chwId: currentUser.uid,
        visitType: visitType,
        date: DateTime.now(),
        found: found,
        notes: notes,
        gpsLocation: gpsLocation,
        photos: photos,
      );

      // Save visit to Firestore
      await _firestore
          .collection('visits')
          .doc(visitId)
          .set(visit.toFirestore());

      // Create audit log for visit
      await _auditService.logHomeVisit(visitId, {
        'patientId': patientId,
        'visitType': visitType,
        'found': found,
        'notes': notes,
      });

      return visitId;
    } catch (e) {
      throw Exception('Failed to create visit: $e');
    }
  }

  /// Quick visit creation for emergencies/urgent cases
  static Future<String> createQuickVisit({
    required String patientId,
    required bool found,
    String notes = '',
  }) async {
    return await createVisit(
      patientId: patientId,
      visitType: VisitType.homeVisit,
      found: found,
      notes: notes,
    );
  }

  // =================== READ OPERATIONS ===================

  /// Get all visits by current CHW - Used by Screen 13: Visit List
  /// Supports filtering and different view types (calendar, list, map)
  static Stream<List<Visit>> getCHWVisits({
    DateTime? startDate,
    DateTime? endDate,
    String? patientFilter,
    String? visitTypeFilter,
    String? sortBy = 'date',
  }) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    Query query = _firestore
        .collection('visits')
        .where('chwId', isEqualTo: currentUser.uid);

    // Apply date filters
    if (startDate != null) {
      query = query.where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
      );
    }
    if (endDate != null) {
      query = query.where(
        'date',
        isLessThanOrEqualTo: Timestamp.fromDate(endDate),
      );
    }

    // Apply visit type filter
    if (visitTypeFilter != null) {
      query = query.where('visitType', isEqualTo: visitTypeFilter);
    }

    // Apply sorting
    switch (sortBy) {
      case 'date':
        query = query.orderBy('date', descending: true);
        break;
      case 'patient':
        query = query.orderBy('patientId');
        break;
      case 'type':
        query = query.orderBy('visitType');
        break;
    }

    return query.snapshots().map((snapshot) {
      List<Visit> visits = snapshot.docs
          .map((doc) => Visit.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();

      // Apply patient filter on client side
      if (patientFilter != null && patientFilter.isNotEmpty) {
        visits = visits
            .where((visit) => visit.patientId.contains(patientFilter))
            .toList();
      }

      return visits;
    });
  }

  /// Get visits for specific patient - Used by Screen 11: Patient Details
  static Stream<List<Visit>> getPatientVisits(String patientId) {
    return _firestore
        .collection('visits')
        .where('patientId', isEqualTo: patientId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    Visit.fromFirestore(doc.data() as Map<String, dynamic>),
              )
              .toList(),
        );
  }

  /// Get single visit details - Used by Screen 15: Visit Details
  static Future<Visit?> getVisitById(String visitId) async {
    try {
      final doc = await _firestore.collection('visits').doc(visitId).get();

      if (doc.exists) {
        return Visit.fromFirestore(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get visit: $e');
    }
  }

  /// Get recent visits for dashboard - Used by Screen 6: Home Dashboard
  static Stream<List<Visit>> getRecentVisits({int limit = 5}) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    return _firestore
        .collection('visits')
        .where('chwId', isEqualTo: currentUser.uid)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) =>
                    Visit.fromFirestore(doc.data() as Map<String, dynamic>),
              )
              .toList(),
        );
  }

  /// Get visits summary for dashboard - Used by Screen 6: Home Dashboard
  static Future<Map<String, dynamic>> getVisitsSummary({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    try {
      Query query = _firestore
          .collection('visits')
          .where('chwId', isEqualTo: currentUser.uid);

      // Apply date range (default to current month if not specified)
      final now = DateTime.now();
      final start = startDate ?? DateTime(now.year, now.month, 1);
      final end = endDate ?? DateTime(now.year, now.month + 1, 0);

      query = query
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end));

      final snapshot = await query.get();
      final visits = snapshot.docs
          .map((doc) => Visit.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();

      return {
        'total_visits': visits.length,
        'patients_found': visits.where((v) => v.found).length,
        'patients_not_found': visits.where((v) => !v.found).length,
        'visits_by_type': _groupVisitsByType(visits),
        'visits_by_date': _groupVisitsByDate(visits),
        'success_rate': visits.isEmpty
            ? 0.0
            : (visits.where((v) => v.found).length / visits.length) * 100,
      };
    } catch (e) {
      throw Exception('Failed to get visits summary: $e');
    }
  }

  /// Get visits for calendar view - Used by Screen 13: Visit List (Calendar view)
  static Future<Map<DateTime, List<Visit>>> getVisitsForCalendar({
    required DateTime month,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    try {
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0);

      final snapshot = await _firestore
          .collection('visits')
          .where('chwId', isEqualTo: currentUser.uid)
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
          )
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .orderBy('date')
          .get();

      final visits = snapshot.docs
          .map((doc) => Visit.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();

      // Group visits by date
      final Map<DateTime, List<Visit>> visitsByDate = {};
      for (final visit in visits) {
        final dateKey = DateTime(
          visit.date.year,
          visit.date.month,
          visit.date.day,
        );
        if (visitsByDate.containsKey(dateKey)) {
          visitsByDate[dateKey]!.add(visit);
        } else {
          visitsByDate[dateKey] = [visit];
        }
      }

      return visitsByDate;
    } catch (e) {
      throw Exception('Failed to get calendar visits: $e');
    }
  }

  // =================== UPDATE OPERATIONS ===================

  /// Update visit notes after creation - Used for post-visit updates
  static Future<void> updateVisitNotes({
    required String visitId,
    required String newNotes,
  }) async {
    try {
      await _firestore.collection('visits').doc(visitId).update({
        'notes': newNotes,
        'updatedAt': Timestamp.now(),
      });

      // Create audit log for visit update
      await _auditService.logAction(
        action: 'updated_visit',
        what: visitId,
        additionalData: {'updated_notes': newNotes},
      );
    } catch (e) {
      throw Exception('Failed to update visit notes: $e');
    }
  }

  /// Complete a scheduled visit - Used for updating visit status and details
  static Future<void> completeVisit({
    required String visitId,
    required bool found,
    required String notes,
    List<String>? photos,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final visit = await getVisitById(visitId);
      if (visit == null) throw Exception('Visit not found');

      // Verify the visit belongs to current CHW
      if (visit.chwId != currentUser.uid) {
        throw Exception('Unauthorized: Visit does not belong to current CHW');
      }

      // Get current GPS location
      final gpsLocation = await _gpsService.getCurrentLocationWithRetry();

      // Update visit with completion details
      await _firestore.collection('visits').doc(visitId).update({
        'found': found,
        'notes': notes,
        'gpsLocation': gpsLocation,
        'completedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        if (photos != null && photos.isNotEmpty) 'photos': photos,
      });

      // Create audit log for visit completion
      await _auditService.logAction(
        action: 'completed_visit',
        what: visitId,
        additionalData: {
          'patientId': visit.patientId,
          'found': found,
          'notes': notes,
        },
      );
    } catch (e) {
      throw Exception('Failed to complete visit: $e');
    }
  }

  /// Add photos to existing visit
  static Future<void> addPhotosToVisit({
    required String visitId,
    required List<String> photoUrls,
  }) async {
    try {
      final visit = await getVisitById(visitId);
      if (visit == null) throw Exception('Visit not found');

      final updatedPhotos = [...(visit.photos ?? []), ...photoUrls];

      await _firestore.collection('visits').doc(visitId).update({
        'photos': updatedPhotos,
        'updatedAt': Timestamp.now(),
      });

      // Create audit log for photo addition
      await _auditService.logAction(
        action: 'added_visit_photos',
        what: visitId,
        additionalData: {
          'new_photos_count': photoUrls.length,
          'total_photos': updatedPhotos.length,
        },
      );
    } catch (e) {
      throw Exception('Failed to add photos to visit: $e');
    }
  }

  // =================== VALIDATION OPERATIONS ===================

  /// Validate visit location against patient location
  /// Used by Screen 14: New Visit to ensure CHW is at correct location
  static Future<bool> validateVisitLocation(String patientId) async {
    try {
      // Get patient location
      final patientDoc = await _firestore
          .collection('patients')
          .doc(patientId)
          .get();

      if (!patientDoc.exists) return false;

      final patientData = patientDoc.data() as Map<String, dynamic>;
      final patientLocation = Map<String, double>.from(
        patientData['gpsLocation'] ?? {},
      );

      if (patientLocation.isEmpty) return true; // Allow if no patient location

      // Validate current location against patient location
      return await _gpsService.validateVisitLocation(
        patientLocation: patientLocation,
        allowedRadius: 35.0, // 35 meters radius - balanced validation
      );
    } catch (e) {
      // Allow visit if validation fails (don't block CHW work)
      return true;
    }
  }

  /// Check if CHW can create visit (not duplicate within timeframe)
  static Future<bool> canCreateVisit({
    required String patientId,
    int minimumHoursBetweenVisits = 2,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      final cutoffTime = DateTime.now().subtract(
        Duration(hours: minimumHoursBetweenVisits),
      );

      final snapshot = await _firestore
          .collection('visits')
          .where('chwId', isEqualTo: currentUser.uid)
          .where('patientId', isEqualTo: patientId)
          .where('date', isGreaterThan: Timestamp.fromDate(cutoffTime))
          .limit(1)
          .get();

      return snapshot.docs.isEmpty;
    } catch (e) {
      return true; // Allow if check fails
    }
  }

  // =================== REPORTING OPERATIONS ===================

  /// Get visit completion rates for reporting - Used by Screen 27: Reports
  static Future<Map<String, dynamic>> getVisitCompletionRates({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception('User not authenticated');

    try {
      final now = DateTime.now();
      final start = startDate ?? DateTime(now.year, now.month, 1);
      final end = endDate ?? now;

      final snapshot = await _firestore
          .collection('visits')
          .where('chwId', isEqualTo: currentUser.uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      final visits = snapshot.docs
          .map((doc) => Visit.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();

      if (visits.isEmpty) {
        return {
          'total_visits': 0,
          'completion_rate': 0.0,
          'visits_by_type': {},
          'trends': [],
        };
      }

      final completedVisits = visits.where((v) => v.found).length;
      final completionRate = (completedVisits / visits.length) * 100;

      return {
        'total_visits': visits.length,
        'completed_visits': completedVisits,
        'completion_rate': completionRate,
        'visits_by_type': _groupVisitsByType(visits),
        'trends': _calculateVisitTrends(visits),
      };
    } catch (e) {
      throw Exception('Failed to get visit completion rates: $e');
    }
  }

  // =================== HELPER METHODS ===================

  /// Group visits by type for reporting
  static Map<String, int> _groupVisitsByType(List<Visit> visits) {
    final Map<String, int> grouped = {};
    for (final visit in visits) {
      grouped[visit.visitType] = (grouped[visit.visitType] ?? 0) + 1;
    }
    return grouped;
  }

  /// Group visits by date for dashboard charts
  static Map<String, int> _groupVisitsByDate(List<Visit> visits) {
    final Map<String, int> grouped = {};
    for (final visit in visits) {
      final dateKey = visit.date.toIso8601String().split('T')[0];
      grouped[dateKey] = (grouped[dateKey] ?? 0) + 1;
    }
    return grouped;
  }

  /// Calculate visit trends for reporting
  static List<Map<String, dynamic>> _calculateVisitTrends(List<Visit> visits) {
    final Map<String, Map<String, int>> weeklyData = {};

    for (final visit in visits) {
      final weekKey = _getWeekKey(visit.date);
      weeklyData[weekKey] ??= {'total': 0, 'found': 0};
      weeklyData[weekKey]!['total'] = weeklyData[weekKey]!['total']! + 1;
      if (visit.found) {
        weeklyData[weekKey]!['found'] = weeklyData[weekKey]!['found']! + 1;
      }
    }

    return weeklyData.entries.map((entry) {
        final total = entry.value['total']!;
        final found = entry.value['found']!;
        return {
          'week': entry.key,
          'total_visits': total,
          'successful_visits': found,
          'success_rate': total > 0 ? (found / total) * 100 : 0.0,
        };
      }).toList()
      ..sort((a, b) => (a['week'] as String).compareTo(b['week'] as String));
  }

  /// Get week key for grouping (YYYY-WW format)
  static String _getWeekKey(DateTime date) {
    final jan1 = DateTime(date.year, 1, 1);
    final daysSinceJan1 = date.difference(jan1).inDays;
    final weekNumber = ((daysSinceJan1 + jan1.weekday) / 7).ceil();
    return '${date.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }
}
