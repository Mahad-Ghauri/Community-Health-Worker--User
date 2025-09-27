// ignore_for_file: avoid_print

import 'package:flutter/widgets.dart';
import '../../models/core_models.dart';
import '../services/patient_service.dart';
import '../services/visit_service.dart';
import '../services/error_handler.dart';

/// Patient Provider - Manages patient state for the entire app
/// Used by: Patient List (8), Patient Search (9), Patient Details (11),
///         Register New Patient (10), Edit Patient (12), Home Dashboard (6)
class PatientProvider with ChangeNotifier {
  // =================== STATE VARIABLES ===================

  List<Patient> _patients = [];
  List<Patient> _searchResults = [];
  Patient? _selectedPatient;
  Map<String, int> _patientStats = {};
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String _statusFilter = 'all_patients';
  String _sortBy = 'name';

  // =================== GETTERS ===================

  List<Patient> get patients => _patients;
  List<Patient> get searchResults => _searchResults;
  Patient? get selectedPatient => _selectedPatient;
  Map<String, int> get patientStats => _patientStats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get statusFilter => _statusFilter;
  String get sortBy => _sortBy;

  // Filtered patients based on current filters
  List<Patient> get filteredPatients {
    List<Patient> filtered = List.from(_patients);

    // Apply status filter
    if (_statusFilter != 'all_patients') {
      filtered = filtered.where((p) => p.tbStatus == _statusFilter).toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (p) =>
                p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                p.phone.contains(_searchQuery) ||
                p.address.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'date':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'status':
        filtered.sort((a, b) => a.tbStatus.compareTo(b.tbStatus));
        break;
    }

    return filtered;
  }

  // =================== PUBLIC METHODS ===================

  /// Initialize patient provider - Called when app starts
  Future<void> initialize() async {
    await loadPatients();
    await loadPatientStats();
  }

  /// Load all assigned patients - Used by Screen 8: Patient List
  Future<void> loadPatients() async {
    try {
      _setLoading(true);
      _clearError();

      // Get patients stream and listen to updates
      PatientService.getAssignedPatients(
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        statusFilter: _statusFilter == 'all_patients' ? null : _statusFilter,
        sortBy: _sortBy,
      ).listen(
        (patients) {
          _patients = patients;
          _setLoading(false);
          notifyListeners();
        },
        onError: (error) {
          _setError('Failed to load patients: $error');
          _setLoading(false);
        },
      );
    } catch (e) {
      _setError('Failed to load patients: $e');
      _setLoading(false);
    }
  }

  /// Search patients - Used by Screen 9: Patient Search
  Future<void> searchPatients(String query) async {
    try {
      _setLoading(true);
      _clearError();
      _searchQuery = query;

      if (query.isEmpty) {
        _searchResults = [];
        _setLoading(false);
        notifyListeners();
        return;
      }

      final results = await PatientService.searchPatients(
        nameQuery: query,
        limit: 20,
      );

      _searchResults = results;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Search failed: $e');
      _setLoading(false);
    }
  }

  /// Register new patient - Used by Screen 10: Register New Patient
  Future<String?> registerPatient({
    required String name,
    required int age,
    required String phone,
    required String address,
    required String gender,
    required String tbStatus,
    required String treatmentFacility,
    required bool consent,
    String? consentSignature,
    DateTime? diagnosisDate,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // Validate patient data
      if (!PatientService.validatePatientData(
        name: name,
        age: age,
        phone: phone,
        address: address,
        consent: consent,
      )) {
        throw Exception('Invalid patient data');
      }

      // Check if patient already exists
      final exists = await PatientService.patientExistsByPhone(phone);
      if (exists) {
        throw Exception('Patient with this phone number already exists');
      }

      final patientId = await PatientService.registerPatient(
        name: name,
        age: age,
        phone: phone,
        address: address,
        gender: gender,
        tbStatus: tbStatus,
        treatmentFacility: treatmentFacility,
        consent: consent,
        consentSignature: consentSignature,
        diagnosisDate: diagnosisDate,
      );

      // Refresh patient list and stats
      await loadPatients();
      await loadPatientStats();

      _setLoading(false);
      return patientId;
    } catch (e) {
      _setError('Failed to register patient: $e');
      _setLoading(false);
      return null;
    }
  }

  /// Select patient for details view - Used by Screen 11: Patient Details
  Future<void> selectPatient(String patientId) async {
    try {
      _setLoading(true);
      _clearError();

      // First try to find the patient in the already loaded list
      Patient? patient;
      try {
        patient = _patients.firstWhere((p) => p.patientId == patientId);
      } catch (e) {
        patient = null;
      }

      // If not found in list, fetch from Firestore
      patient ??= await PatientService.getPatientById(patientId);

      if (patient == null) {
        throw Exception('Patient with ID $patientId not found');
      }

      _selectedPatient = patient;

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load patient details: $e');
      _setLoading(false);
    }
  }

  /// Select patient directly from patient object (more efficient)
  void selectPatientDirect(Patient patient) {
    _selectedPatient = patient;
    notifyListeners();
  }

  /// Update patient - Used by Screen 12: Edit Patient
  Future<bool> updatePatient({
    required String patientId,
    required Map<String, dynamic> updates,
    required String reasonForChanges,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      await PatientService.updatePatient(
        patientId: patientId,
        updates: updates,
        reasonForChanges: reasonForChanges,
      );

      // Refresh selected patient and list
      await selectPatient(patientId);
      await loadPatients();

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to update patient: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Load patient statistics for dashboard - Used by Screen 6: Home Dashboard
  Future<void> loadPatientStats() async {
    try {
      final stats = await PatientService.getPatientStats();
      _patientStats = stats;
      notifyListeners();
    } catch (e) {
      print('Failed to load patient stats: $e');
    }
  }

  /// Set filters for patient list - Used by Screen 8: Patient List
  void setFilters({String? searchQuery, String? statusFilter, String? sortBy}) {
    bool needsRefresh = false;

    if (searchQuery != null && searchQuery != _searchQuery) {
      _searchQuery = searchQuery;
      needsRefresh = true;
    }

    if (statusFilter != null && statusFilter != _statusFilter) {
      _statusFilter = statusFilter;
      needsRefresh = true;
    }

    if (sortBy != null && sortBy != _sortBy) {
      _sortBy = sortBy;
      needsRefresh = true;
    }

    if (needsRefresh) {
      loadPatients();
    }
  }

  /// Clear search results
  void clearSearch() {
    _searchResults = [];
    _searchQuery = '';
    notifyListeners();
  }

  /// Clear selected patient
  void clearSelectedPatient() {
    _selectedPatient = null;
    notifyListeners();
  }

  /// Update patient status - Used when visit outcomes change status
  Future<void> updatePatientStatus(String patientId, String newStatus) async {
    try {
      await PatientService.updatePatientStatus(patientId, newStatus);

      // Update local state
      if (_selectedPatient?.patientId == patientId) {
        await selectPatient(patientId);
      }

      // Refresh patient list and stats
      await loadPatients();
      await loadPatientStats();
    } catch (e) {
      _setError('Failed to update patient status: $e');
    }
  }

  // =================== PRIVATE METHODS ===================

  void _setLoading(bool loading) {
    _isLoading = loading;
    // Defer notifyListeners to avoid calling during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void _setError(String error) {
    _error = ErrorHandler.getUserFriendlyMessage(error);
    // Defer notifyListeners to avoid calling during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void _clearError() {
    _error = null;
  }

  @override
  void dispose() {
    // Clean up any active streams or resources
    super.dispose();
  }
}

/// Visit Provider - Manages visit state for the entire app
/// Used by: New Visit (14), Visit List (13), Visit Details (15), Home Dashboard (6)
class VisitProvider with ChangeNotifier {
  // =================== STATE VARIABLES ===================

  List<Visit> _visits = [];
  List<Visit> _recentVisits = [];
  Visit? _selectedVisit;
  Map<String, dynamic> _visitsSummary = {};
  Map<DateTime, List<Visit>> _calendarVisits = {};
  bool _isLoading = false;
  String? _error;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _patientFilter;
  String? _visitTypeFilter;
  String _sortBy = 'date';

  // =================== GETTERS ===================

  List<Visit> get visits => _visits;
  List<Visit> get recentVisits => _recentVisits;
  Visit? get selectedVisit => _selectedVisit;
  Map<String, dynamic> get visitsSummary => _visitsSummary;
  Map<DateTime, List<Visit>> get calendarVisits => _calendarVisits;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String? get patientFilter => _patientFilter;
  String? get visitTypeFilter => _visitTypeFilter;
  String get sortBy => _sortBy;

  // =================== PUBLIC METHODS ===================

  /// Initialize visit provider - Called when app starts
  Future<void> initialize() async {
    await loadVisits();
    await loadRecentVisits();
    await loadVisitsSummary();
  }

  /// Load all CHW visits - Used by Screen 13: Visit List
  Future<void> loadVisits() async {
    try {
      _setLoading(true);
      _clearError();

      // Get visits stream and listen to updates
      VisitService.getCHWVisits(
        startDate: _startDate,
        endDate: _endDate,
        patientFilter: _patientFilter,
        visitTypeFilter: _visitTypeFilter,
        sortBy: _sortBy,
      ).listen(
        (visits) {
          _visits = visits;
          _setLoading(false);
          notifyListeners();
        },
        onError: (error) {
          _setError('Failed to load visits: $error');
          _setLoading(false);
        },
      );
    } catch (e) {
      _setError('Failed to load visits: $e');
      _setLoading(false);
    }
  }

  /// Create new visit - Used by Screen 14: New Visit
  Future<String?> createVisit({
    required String patientId,
    required String visitType,
    required bool found,
    required String notes,
    List<String>? photos,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // Validate if visit can be created
      final canCreate = await VisitService.canCreateVisit(patientId: patientId);
      if (!canCreate) {
        throw Exception(
          'You cannot create another visit for this patient yet. Please wait at least 2 hours between visits.',
        );
      }

      // Validate location if GPS is available
      final locationValid = await VisitService.validateVisitLocation(patientId);
      if (!locationValid) {
        // Still allow visit but log warning
        print('Warning: Visit location validation failed');
      }

      final visitId = await VisitService.createVisit(
        patientId: patientId,
        visitType: visitType,
        found: found,
        notes: notes,
        photos: photos,
      );

      // Refresh visit data
      await loadVisits();
      await loadRecentVisits();
      await loadVisitsSummary();

      _setLoading(false);
      return visitId;
    } catch (e) {
      _setError('Failed to create visit: $e');
      _setLoading(false);
      return null;
    }
  }

  /// Load recent visits for dashboard - Used by Screen 6: Home Dashboard
  Future<void> loadRecentVisits() async {
    try {
      VisitService.getRecentVisits(limit: 5).listen(
        (visits) {
          _recentVisits = visits;
          notifyListeners();
        },
        onError: (error) {
          print('Failed to load recent visits: $error');
        },
      );
    } catch (e) {
      print('Failed to load recent visits: $e');
    }
  }

  /// Load visits summary for dashboard - Used by Screen 6: Home Dashboard
  Future<void> loadVisitsSummary() async {
    try {
      final summary = await VisitService.getVisitsSummary();
      _visitsSummary = summary;
      notifyListeners();
    } catch (e) {
      print('Failed to load visits summary: $e');
    }
  }

  /// Select visit for details view - Used by Screen 15: Visit Details
  Future<void> selectVisit(String visitId) async {
    try {
      _setLoading(true);
      _clearError();

      final visit = await VisitService.getVisitById(visitId);
      _selectedVisit = visit;

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load visit details: $e');
      _setLoading(false);
    }
  }

  /// Load visits for calendar view - Used by Screen 13: Visit List (Calendar)
  Future<void> loadCalendarVisits(DateTime month) async {
    try {
      _setLoading(true);
      _clearError();

      final calendarData = await VisitService.getVisitsForCalendar(
        month: month,
      );
      _calendarVisits = calendarData;

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load calendar visits: $e');
      _setLoading(false);
    }
  }

  /// Get visits for specific patient - Used by Screen 11: Patient Details
  Stream<List<Visit>> getPatientVisits(String patientId) {
    return VisitService.getPatientVisits(patientId);
  }

  /// Set filters for visit list - Used by Screen 13: Visit List
  void setFilters({
    DateTime? startDate,
    DateTime? endDate,
    String? patientFilter,
    String? visitTypeFilter,
    String? sortBy,
  }) {
    bool needsRefresh = false;

    if (startDate != _startDate) {
      _startDate = startDate;
      needsRefresh = true;
    }

    if (endDate != _endDate) {
      _endDate = endDate;
      needsRefresh = true;
    }

    if (patientFilter != _patientFilter) {
      _patientFilter = patientFilter;
      needsRefresh = true;
    }

    if (visitTypeFilter != _visitTypeFilter) {
      _visitTypeFilter = visitTypeFilter;
      needsRefresh = true;
    }

    if (sortBy != null && sortBy != _sortBy) {
      _sortBy = sortBy;
      needsRefresh = true;
    }

    if (needsRefresh) {
      loadVisits();
    }
  }

  /// Clear filters
  void clearFilters() {
    _startDate = null;
    _endDate = null;
    _patientFilter = null;
    _visitTypeFilter = null;
    _sortBy = 'date';
    loadVisits();
  }

  /// Clear selected visit
  void clearSelectedVisit() {
    _selectedVisit = null;
    notifyListeners();
  }

  /// Update visit notes - Used for post-visit updates
  Future<bool> updateVisitNotes(String visitId, String newNotes) async {
    try {
      _setLoading(true);
      _clearError();

      await VisitService.updateVisitNotes(visitId: visitId, newNotes: newNotes);

      // Refresh selected visit and list
      await selectVisit(visitId);
      await loadVisits();

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to update visit notes: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Add photos to visit
  Future<bool> addPhotosToVisit(String visitId, List<String> photoUrls) async {
    try {
      _setLoading(true);
      _clearError();

      await VisitService.addPhotosToVisit(
        visitId: visitId,
        photoUrls: photoUrls,
      );

      // Refresh selected visit and list
      await selectVisit(visitId);
      await loadVisits();

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to add photos: $e');
      _setLoading(false);
      return false;
    }
  }

  // =================== PRIVATE METHODS ===================

  void _setLoading(bool loading) {
    _isLoading = loading;
    // Defer notifyListeners to avoid calling during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void _setError(String error) {
    _error = ErrorHandler.getUserFriendlyMessage(error);
    // Defer notifyListeners to avoid calling during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void _clearError() {
    _error = null;
  }

  @override
  void dispose() {
    // Clean up any active streams or resources
    super.dispose();
  }
}
