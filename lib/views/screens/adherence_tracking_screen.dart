// ignore_for_file: deprecated_member_use, unnecessary_to_list_in_spreads, avoid_print, avoid_types_as_parameter_names

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chw_tb/config/theme.dart';
import 'package:chw_tb/controllers/providers/secondary_providers.dart';
import 'package:chw_tb/models/medicine.dart';
import 'package:chw_tb/models/core_models.dart';

class AdherenceTrackingScreen extends StatefulWidget {
  final String? patientId;

  const AdherenceTrackingScreen({super.key, this.patientId});

  @override
  State<AdherenceTrackingScreen> createState() =>
      _AdherenceTrackingScreenState();
}

class _AdherenceTrackingScreenState extends State<AdherenceTrackingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  // Dose tracking for current day
  final Map<String, String> _morningDoses = {};
  final Map<String, String> _eveningDoses = {};
  final Map<String, String> _nightDoses = {};

  // Side effects tracking
  final List<String> _reportedSideEffects = [];
  // ignore: unused_field
  String _sideEffectNotes = '';

  // Pill count
  final Map<String, int> _pillCounts = {};

  final List<String> _doseOptions = ['taken', 'missed', 'late', 'vomited'];

  List<Medication> _medications = [];
  bool _isLoadingMedications = true;

  // Patient data
  Patient? _patient;
  bool _isLoadingPatient = true;

  // Adherence history for calculations
  List<TreatmentAdherence> _adherenceHistory = [];
  bool _isLoadingAdherence = true;
  bool _hasRecordedToday = false;

  // Date selection for backdated entries
  DateTime _selectedDate = DateTime.now();
  bool _isBackdatedEntry = false;

  final List<String> _sideEffectsList = [
    'nausea',
    'vomiting',
    'rash',
    'dizziness',
    'hearing_problems',
    'joint_pain',
    'vision_changes',
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _tabController = TabController(length: 4, vsync: this);
    _fadeController.forward();

    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (widget.patientId == null) return;

    // Load patient, medications, and adherence history first
    await Future.wait([
      _loadPatient(),
      _loadMedications(),
      _loadAdherenceHistory(),
    ]);

    // After all data is loaded, initialize dose tracking with today's data
    _initializeDoseTracking();

    _loadAdherenceData();
  }

  Future<void> _loadPatient() async {
    if (widget.patientId == null) return;

    try {
      setState(() {
        _isLoadingPatient = true;
      });

      final doc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(widget.patientId)
          .get();

      if (doc.exists) {
        setState(() {
          _patient = Patient.fromFirestore(doc.data()!);
          _isLoadingPatient = false;
        });
      } else {
        setState(() {
          _isLoadingPatient = false;
        });
      }
    } catch (e) {
      print('Error loading patient: $e');
      setState(() {
        _isLoadingPatient = false;
      });
    }
  }

  Future<void> _loadAdherenceHistory() async {
    if (widget.patientId == null) return;

    try {
      setState(() {
        _isLoadingAdherence = true;
      });

      final querySnapshot = await FirebaseFirestore.instance
          .collection('treatmentAdherence')
          .where('patientId', isEqualTo: widget.patientId)
          .orderBy('date', descending: true)
          .limit(30) // Last 30 days
          .get();

      List<TreatmentAdherence> adherenceHistory = [];

      for (var doc in querySnapshot.docs) {
        try {
          var adherenceRecord = TreatmentAdherence.fromFirestore(doc.data());
          adherenceHistory.add(adherenceRecord);
        } catch (e) {
          print('Error parsing adherence document ${doc.id}: $e');
        }
      }

      setState(() {
        _adherenceHistory = adherenceHistory;
        _isLoadingAdherence = false;
        _hasRecordedToday = _checkIfRecordedToday();
      });
    } catch (e) {
      print('Error loading adherence history: $e');
      setState(() {
        _isLoadingAdherence = false;
      });
    }
  }

  bool _checkIfRecordedToday() {
    final today = DateTime.now();
    return _adherenceHistory.any((record) {
      final recordDate = record.date;
      return recordDate.year == today.year &&
          recordDate.month == today.month &&
          recordDate.day == today.day;
    });
  }

  bool _checkIfRecordedForSelectedDate() {
    final selectedDateOnly = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    return _adherenceHistory.any((record) {
      final recordDate = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      return recordDate.isAtSameMomentAs(selectedDateOnly);
    });
  }

  Future<void> _loadMedications() async {
    if (widget.patientId == null) return;

    try {
      setState(() {
        _isLoadingMedications = true;
      });

      final querySnapshot = await FirebaseFirestore.instance
          .collection('medications')
          .where('patientId', isEqualTo: widget.patientId)
          .where('isActive', isEqualTo: true)
          .get();

      final List<Medication> medications = [];
      for (var doc in querySnapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        bool needsUpdate = false;

        // Normalize startDate
        final sd = data['startDate'];
        if (sd is String) {
          final parsed = DateTime.tryParse(sd);
          if (parsed != null) {
            data['startDate'] = Timestamp.fromDate(parsed);
            needsUpdate = true;
          }
        }

        // Normalize endDate
        final ed = data['endDate'];
        if (ed is String) {
          final parsed = DateTime.tryParse(ed);
          if (parsed != null) {
            data['endDate'] = Timestamp.fromDate(parsed);
            needsUpdate = true;
          }
        }

        if (needsUpdate) {
          try {
            await doc.reference.update({
              'startDate': data['startDate'],
              'endDate': data['endDate'],
            });
          } catch (e) {
            // Log but continue
            print('Failed to normalize medication dates for ${doc.id}: $e');
          }
        }

        medications.add(Medication.fromFirestore(data, docId: doc.id));
      }

      setState(() {
        _medications = medications;
        _isLoadingMedications = false;
      });
    } catch (e) {
      print('Error loading medications: $e');
      setState(() {
        _isLoadingMedications = false;
      });
    }
  }

  Color _getMedicationColor(String medicationName) {
    // Assign colors based on medication name for visual distinction
    switch (medicationName.toLowerCase()) {
      case 'rifampin':
      case 'rifampicin':
        return Colors.red;
      case 'isoniazid':
        return Colors.blue;
      case 'ethambutol':
        return Colors.green;
      case 'pyrazinamide':
        return Colors.orange;
      case 'streptomycin':
        return Colors.purple;
      default:
        // Generate a color based on the medication name hash
        final hash = medicationName.hashCode;
        final colors = [
          Colors.teal,
          Colors.indigo,
          Colors.pink,
          Colors.amber,
          Colors.deepOrange,
          Colors.cyan,
        ];
        return colors[hash.abs() % colors.length];
    }
  }

  // Medication/date helpers
  bool _isMedicationActiveOnDate(Medication med, DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final start = DateTime(
      med.startDate.year,
      med.startDate.month,
      med.startDate.day,
    );
    final end = med.endDate != null
        ? DateTime(med.endDate!.year, med.endDate!.month, med.endDate!.day)
        : null;
    if (d.isBefore(start)) return false;
    if (end != null && d.isAfter(end)) return false;
    if (!med.isActive && (end == null || d.isAfter(end))) return false;
    return true;
  }

  // Normalize med names to match dose keys variations
  String _normalizeMedName(String name) {
    return name
        .toLowerCase()
        .replaceAll(' (r)', '')
        .replaceAll(' (h)', '')
        .replaceAll(' (e)', '')
        .replaceAll(' (z)', '')
        .replaceAll('(r)', '')
        .replaceAll('(h)', '')
        .replaceAll('(e)', '')
        .replaceAll('(z)', '')
        .replaceAll('rifampin', 'rifampicin')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Medication? _findMedicationByName(String name) {
    final normalized = _normalizeMedName(name);
    try {
      return _medications.firstWhere(
        (m) => _normalizeMedName(m.name) == normalized,
      );
    } catch (_) {
      return null;
    }
  }

  // Dynamic calculation methods
  Map<String, dynamic> _calculateAdherenceStats() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));

    // Get today's adherence record if it exists
    TreatmentAdherence? todayRecord =
        _adherenceHistory.where((record) {
          final recordDate = DateTime(
            record.date.year,
            record.date.month,
            record.date.day,
          );
          return recordDate.isAtSameMomentAs(today);
        }).isNotEmpty
        ? _adherenceHistory.where((record) {
            final recordDate = DateTime(
              record.date.year,
              record.date.month,
              record.date.day,
            );
            return recordDate.isAtSameMomentAs(today);
          }).first
        : null;

    // Weekly adherence calculation
    Map<DateTime, TreatmentAdherence> weeklyRecordsMap = {};

    // Add historical weekly records
    for (var record in _adherenceHistory) {
      final recordDate = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      if (recordDate.isAfter(weekAgo.subtract(const Duration(days: 1))) &&
          recordDate.isBefore(today.add(const Duration(days: 1)))) {
        weeklyRecordsMap[recordDate] = record;
      }
    }

    // If today hasn't been recorded yet, use current tracking data
    if (todayRecord == null && !_hasRecordedToday) {
      Map<String, String> todaysDoses = {};

      // Add morning doses with timing suffix
      for (var entry in _morningDoses.entries) {
        if (entry.value.isNotEmpty) {
          todaysDoses['${entry.key}_morning'] = entry.value;
        }
      }

      // Add evening doses with timing suffix
      for (var entry in _eveningDoses.entries) {
        if (entry.value.isNotEmpty) {
          todaysDoses['${entry.key}_evening'] = entry.value;
        }
      }

      // Add night doses with timing suffix
      for (var entry in _nightDoses.entries) {
        if (entry.value.isNotEmpty) {
          todaysDoses['${entry.key}_night'] = entry.value;
        }
      }

      if (todaysDoses.isNotEmpty) {
        // Create a temporary record for today's tracking
        int takenCount = todaysDoses.values
            .where((dose) => dose == 'taken')
            .length;
        double todayScore = todaysDoses.isNotEmpty
            ? (takenCount / todaysDoses.length) * 100
            : 0;

        weeklyRecordsMap[today] = TreatmentAdherence(
          adherenceId: 'temp_${today.millisecondsSinceEpoch}',
          patientId: widget.patientId!,
          date: now,
          reportedBy: 'current_user', // You might want to get the actual CHW ID
          dosesToday: todaysDoses,
          sideEffects: _reportedSideEffects,
          pillsRemaining: Map<String, int>.from(_pillCounts),
          adherenceScore: todayScore,
          counselingGiven: true,
          notes: 'Current tracking',
        );
      }
    }

    // Calculate weekly statistics
    int weeklyTotalDoses = 0;
    int weeklyTakenDoses = 0;

    for (var record in weeklyRecordsMap.values) {
      // Only count doses for medications active on that record date
      final recordDateOnly = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      int dayTotal = 0;
      int dayTaken = 0;
      record.dosesToday.forEach((key, dose) {
        final medName = key
            .replaceAll('_morning', '')
            .replaceAll('_evening', '')
            .replaceAll('_night', '');
        final med = _findMedicationByName(medName);
        if (med != null && _isMedicationActiveOnDate(med, recordDateOnly)) {
          dayTotal += 1;
          if (dose == 'taken') dayTaken += 1;
        }
      });
      weeklyTotalDoses += dayTotal;
      weeklyTakenDoses += dayTaken;
    }

    double weeklyScore = weeklyTotalDoses > 0
        ? (weeklyTakenDoses / weeklyTotalDoses) * 100
        : 0;

    // Overall adherence calculation - all historical data plus today if not recorded
    int overallTotalDoses = 0;
    int overallTakenDoses = 0;

    // Group all records by date to avoid duplicates
    Map<DateTime, TreatmentAdherence> allRecordsMap = {};

    for (var record in _adherenceHistory) {
      final recordDate = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      allRecordsMap[recordDate] = record;
    }

    // Add today's data if not already recorded
    if (todayRecord == null && !_hasRecordedToday) {
      Map<String, String> todaysDoses = {};

      // Add morning doses with timing suffix
      for (var entry in _morningDoses.entries) {
        if (entry.value.isNotEmpty) {
          todaysDoses['${entry.key}_morning'] = entry.value;
        }
      }

      // Add evening doses with timing suffix
      for (var entry in _eveningDoses.entries) {
        if (entry.value.isNotEmpty) {
          todaysDoses['${entry.key}_evening'] = entry.value;
        }
      }

      // Add night doses with timing suffix
      for (var entry in _nightDoses.entries) {
        if (entry.value.isNotEmpty) {
          todaysDoses['${entry.key}_night'] = entry.value;
        }
      }

      if (todaysDoses.isNotEmpty) {
        int takenCount = todaysDoses.values
            .where((dose) => dose == 'taken')
            .length;
        double todayScore = todaysDoses.isNotEmpty
            ? (takenCount / todaysDoses.length) * 100
            : 0;

        allRecordsMap[today] = TreatmentAdherence(
          adherenceId: 'temp_${today.millisecondsSinceEpoch}',
          patientId: widget.patientId!,
          date: now,
          reportedBy: 'current_user', // You might want to get the actual CHW ID
          dosesToday: todaysDoses,
          sideEffects: _reportedSideEffects,
          pillsRemaining: Map<String, int>.from(_pillCounts),
          adherenceScore: todayScore,
          counselingGiven: true,
          notes: 'Current tracking',
        );
      }
    }

    // Calculate overall statistics
    for (var record in allRecordsMap.values) {
      final recordDateOnly = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      int dayTotal = 0;
      int dayTaken = 0;
      record.dosesToday.forEach((key, dose) {
        final medName = key
            .replaceAll('_morning', '')
            .replaceAll('_evening', '')
            .replaceAll('_night', '');
        final med = _findMedicationByName(medName);
        if (med != null && _isMedicationActiveOnDate(med, recordDateOnly)) {
          dayTotal += 1;
          if (dose == 'taken') dayTaken += 1;
        }
      });
      overallTotalDoses += dayTotal;
      overallTakenDoses += dayTaken;
    }

    double overallScore = overallTotalDoses > 0
        ? (overallTakenDoses / overallTotalDoses) * 100
        : 0;

    return {
      'weekly_score': weeklyScore,
      'overall_score': overallScore,
      'total_doses': overallTotalDoses,
      'taken_doses': overallTakenDoses,
      'weekly_days': weeklyRecordsMap.length,
      'total_days': allRecordsMap.length,
    };
  }

  List<Map<String, dynamic>> _getRecentSideEffects() {
    if (_adherenceHistory.isEmpty) return [];

    return _adherenceHistory.take(7).map((record) {
      return {
        'date': _formatDate(record.date),
        'effects': record.sideEffects,
        'severity': record.sideEffects.isEmpty
            ? 'None'
            : 'Mild', // You can enhance this logic
      };
    }).toList();
  }

  List<Map<String, dynamic>> _getPillCountHistory() {
    List<Map<String, dynamic>> pillHistory = [];
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Add today's data if available (either from current tracking or recorded)
    TreatmentAdherence? todayRecord =
        _adherenceHistory.where((record) {
          final recordDate = DateTime(
            record.date.year,
            record.date.month,
            record.date.day,
          );
          return recordDate.isAtSameMomentAs(todayDate);
        }).isNotEmpty
        ? _adherenceHistory.where((record) {
            final recordDate = DateTime(
              record.date.year,
              record.date.month,
              record.date.day,
            );
            return recordDate.isAtSameMomentAs(todayDate);
          }).first
        : null;

    if (todayRecord != null) {
      // Use recorded data for today
      int totalPills = todayRecord.pillsRemaining.values.fold(
        0,
        (sum, count) => sum + count,
      );
      bool needsRefill = todayRecord.pillsRemaining.values.any(
        (count) => count <= 10,
      );

      pillHistory.add({
        'date': 'Today',
        'count': '$totalPills pills total',
        'status': needsRefill ? 'Refill needed' : 'On track',
        'details': todayRecord.pillsRemaining,
      });
    } else if (!_hasRecordedToday && _pillCounts.isNotEmpty) {
      // Use current tracking data for today
      int totalPills = _pillCounts.values.fold(0, (sum, count) => sum + count);
      bool needsRefill = _pillCounts.values.any((count) => count <= 10);

      pillHistory.add({
        'date': 'Today (Current)',
        'count': '$totalPills pills total',
        'status': needsRefill ? 'Refill needed' : 'On track',
        'details': Map<String, int>.from(_pillCounts),
      });
    }

    // Add historical data (excluding today if already added)
    final historicalRecords = _adherenceHistory
        .where((record) {
          final recordDate = DateTime(
            record.date.year,
            record.date.month,
            record.date.day,
          );
          return !recordDate.isAtSameMomentAs(todayDate);
        })
        .take(6)
        .toList(); // Take 6 more to make 7 total

    for (var record in historicalRecords) {
      int totalPills = record.pillsRemaining.values.fold(
        0,
        (sum, count) => sum + count,
      );
      bool needsRefill = record.pillsRemaining.values.any(
        (count) => count <= 10,
      );

      pillHistory.add({
        'date': _formatDate(record.date),
        'count': '$totalPills pills total',
        'status': needsRefill ? 'Refill needed' : 'On track',
        'details': record.pillsRemaining,
      });
    }

    return pillHistory;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final difference = today.difference(dateOnly).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference > 0 && difference < 7) return '$difference days ago';
    if (difference < 0) {
      // Future date
      final futureDays = difference.abs();
      if (futureDays == 1) return 'Tomorrow';
      if (futureDays < 7) return 'In $futureDays days';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatSelectedDate() {
    final difference = DateTime.now().difference(_selectedDate).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '$difference daysx ago';
    return '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';
  }

  Future<void> _selectDate() async {
    // Calculate treatment date range based on patient's medications
    DateTime? treatmentStartDate;
    DateTime? treatmentEndDate;

    if (_medications.isNotEmpty) {
      // Find the earliest start date and latest end date from all medications
      treatmentStartDate = _medications
          .map((med) => med.startDate)
          .reduce(
            (earliest, current) =>
                current.isBefore(earliest) ? current : earliest,
          );

      // Find the latest end date (if any medication has no end date, allow current date)
      var endDates = _medications
          .where((med) => med.endDate != null)
          .map((med) => med.endDate!)
          .toList();

      if (endDates.isNotEmpty) {
        treatmentEndDate = endDates.reduce(
          (latest, current) => current.isAfter(latest) ? current : latest,
        );
      }
    }

    // Helper to strip time components to date-only values
    DateTime d(DateTime d) => DateTime(d.year, d.month, d.day);

    // Default fallback dates if no medication data (date-only)
    final today = d(DateTime.now());
    final defaultStartDate = treatmentStartDate != null
        ? d(treatmentStartDate)
        : today.subtract(const Duration(days: 30));

    // Ensure we don't allow future dates beyond today; use date-only values
    final endCandidate = treatmentEndDate != null
        ? d(treatmentEndDate)
        : today;
    final actualEndDate = endCandidate.isAfter(today) ? today : endCandidate;

    // Clamp initial date within [defaultStartDate, actualEndDate]
    DateTime initialDate = d(_selectedDate);
    if (initialDate.isBefore(defaultStartDate)) initialDate = defaultStartDate;
    if (initialDate.isAfter(actualEndDate)) initialDate = actualEndDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: defaultStartDate,
      lastDate: actualEndDate,
      helpText: 'Select date for adherence entry',
      errorFormatText: 'Invalid date format',
      errorInvalidText: 'Date must be within treatment period',
      fieldLabelText: 'Enter date',
      fieldHintText: 'mm/dd/yyyy',
      selectableDayPredicate: (d) {
        final dd = DateTime(d.year, d.month, d.day);
        return !dd.isBefore(defaultStartDate) && !dd.isAfter(actualEndDate);
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: MadadgarTheme.primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      // Additional validation before accepting the selected date
      if (_isValidTreatmentDate(picked)) {
        setState(() {
          _selectedDate = picked;
          _isBackdatedEntry = !_isSameDay(picked, DateTime.now());
        });

        // Reload data for the selected date
        _loadSelectedDateData();
      } else {
        // Show error message for invalid date selection
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Selected date is outside the treatment period. Please choose a date between ${_formatDate(defaultStartDate)} and ${_formatDate(actualEndDate)}.',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  bool _isValidTreatmentDate(DateTime selectedDate) {
    if (_medications.isEmpty) {
      // No medications loaded: disallow backdated entries
      final today = DateTime.now();
      final sel = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );
      final tOnly = DateTime(today.year, today.month, today.day);
      return sel.isAtSameMomentAs(tOnly);
    }

    // Find the earliest start date and latest end date from all medications
    DateTime earliestStart = _medications
        .map((med) => med.startDate)
        .reduce(
          (earliest, current) =>
              current.isBefore(earliest) ? current : earliest,
        );

    // Latest end is either the latest med endDate or today if some are ongoing
    DateTime latestEnd = DateTime.now();
    var endDates = _medications
        .where((med) => med.endDate != null)
        .map((med) => med.endDate!)
        .toList();
    if (endDates.isNotEmpty) {
      final calculatedEnd = endDates.reduce(
        (latest, current) => current.isAfter(latest) ? current : latest,
      );
      latestEnd = calculatedEnd.isBefore(DateTime.now())
          ? calculatedEnd
          : DateTime.now();
    }

    // Inclusive day-level comparison
    final sel = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final startOnly = DateTime(
      earliestStart.year,
      earliestStart.month,
      earliestStart.day,
    );
    final endOnly = DateTime(latestEnd.year, latestEnd.month, latestEnd.day);

    final isAfterOrOnStart = !sel.isBefore(startOnly);
    final isBeforeOrOnEnd = !sel.isAfter(endOnly);
    return isAfterOrOnStart && isBeforeOrOnEnd;
  }

  String _getTreatmentPeriodInfo() {
    if (_medications.isEmpty) {
      return 'No medication data available';
    }

    DateTime earliestStart = _medications
        .map((med) => med.startDate)
        .reduce(
          (earliest, current) =>
              current.isBefore(earliest) ? current : earliest,
        );

    var endDates = _medications
        .where((med) => med.endDate != null)
        .map((med) => med.endDate!)
        .toList();

    String result;
    if (endDates.isNotEmpty) {
      DateTime latestEnd = endDates.reduce(
        (latest, current) => current.isAfter(latest) ? current : latest,
      );
      result =
          'Treatment period: ${_formatDate(earliestStart)} to ${_formatDate(latestEnd)}';
    } else {
      result = 'Treatment started: ${_formatDate(earliestStart)} (ongoing)';
    }

    return result;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  void _loadSelectedDateData() {
    final selectedDateOnly = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    // Check if selected date's data has been recorded in Firestore
    TreatmentAdherence? selectedDateRecord =
        _adherenceHistory.where((record) {
          final recordDate = DateTime(
            record.date.year,
            record.date.month,
            record.date.day,
          );
          bool matches = recordDate.isAtSameMomentAs(selectedDateOnly);
          return matches;
        }).isNotEmpty
        ? _adherenceHistory.where((record) {
            final recordDate = DateTime(
              record.date.year,
              record.date.month,
              record.date.day,
            );
            return recordDate.isAtSameMomentAs(selectedDateOnly);
          }).first
        : null;

    if (selectedDateRecord != null) {
      // Load the saved data from Firestore into the tracking maps
      setState(() {
        // Clear current tracking data
        _morningDoses.clear();
        _eveningDoses.clear();
        _nightDoses.clear();
        _reportedSideEffects.clear();

        // Load doses from saved record
        for (var entry in selectedDateRecord.dosesToday.entries) {
          String doseKey = entry.key;
          String doseStatus = entry.value;

          // Check if the dose key contains timing information
          if (doseKey.contains('_morning')) {
            String medicationName = doseKey.replaceAll('_morning', '');
            _morningDoses[medicationName] = doseStatus;
          } else if (doseKey.contains('_evening')) {
            String medicationName = doseKey.replaceAll('_evening', '');
            _eveningDoses[medicationName] = doseStatus;
          } else if (doseKey.contains('_night')) {
            String medicationName = doseKey.replaceAll('_night', '');
            _nightDoses[medicationName] = doseStatus;
          } else {
            // For backward compatibility
            String medicationName = doseKey;
            for (var medication in _medications) {
              if (medication.name == medicationName) {
                String frequency = medication.frequency.toLowerCase();
                if (frequency.contains('once') ||
                    frequency.contains('daily') ||
                    frequency == '1') {
                  _morningDoses[medicationName] = doseStatus;
                } else {
                  _morningDoses[medicationName] = doseStatus;
                }
                break;
              }
            }
          }
        }

        // Load side effects
        _reportedSideEffects.addAll(selectedDateRecord.sideEffects);

        // Load pill counts
        for (var entry in selectedDateRecord.pillsRemaining.entries) {
          _pillCounts[entry.key] = entry.value;
        }
      });
    } else {
      // Clear data for new entry
      setState(() {
        _morningDoses.clear();
        _eveningDoses.clear();
        _nightDoses.clear();
        _reportedSideEffects.clear();

        // Reinitialize for selected date
        _initializeDoseTracking();
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _initializeDoseTracking() {
    for (var medication in _medications) {
      // Only initialize doses for medications active on the selected date
      if (!_isMedicationActiveOnDate(medication, _selectedDate)) {
        continue;
      }

      // Initialize based on frequency
      String frequency = medication.frequency.toLowerCase();

      if (frequency.contains('once') ||
          frequency.contains('daily') ||
          frequency == '1') {
        // Once daily - morning only
        _morningDoses[medication.name] = '';
      } else if (frequency.contains('twice') || frequency.contains('2')) {
        // Twice daily - morning and evening
        _morningDoses[medication.name] = '';
        _eveningDoses[medication.name] = '';
      } else if (frequency.contains('thrice') ||
          frequency.contains('three') ||
          frequency.contains('3')) {
        // Three times daily - morning, evening, and night
        _morningDoses[medication.name] = '';
        _eveningDoses[medication.name] = '';
        _nightDoses[medication.name] = '';
      } else {
        // Default to once daily if frequency is unclear
        _morningDoses[medication.name] = '';
      }

      // Initialize pill count based on recent adherence records
      if (_adherenceHistory.isNotEmpty) {
        // Find the most recent adherence record that has this medication
        final recentRecord = _adherenceHistory.firstWhere(
          (record) => record.pillsRemaining.containsKey(medication.name),
          orElse: () => TreatmentAdherence(
            adherenceId: '',
            patientId: '',
            date: DateTime.now(),
            reportedBy: '',
            dosesToday: {},
            sideEffects: [],
            pillsRemaining: {}, // Empty map as default
            adherenceScore: 0,
            counselingGiven: false,
            notes: '',
          ),
        );
        _pillCounts[medication.name] =
            recentRecord.pillsRemaining[medication.name] ??
            medication.pillCount;
      } else {
        // Use medication's default pill count
        _pillCounts[medication.name] = medication.pillCount;
      }
    }

    // Load today's tracking data if it exists and hasn't been saved yet
    _loadTodaysTrackingData();
  }

  void _loadTodaysTrackingData() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Check if today's data has been recorded in Firestore
    TreatmentAdherence? todayRecord =
        _adherenceHistory.where((record) {
          final recordDate = DateTime(
            record.date.year,
            record.date.month,
            record.date.day,
          );
          return recordDate.isAtSameMomentAs(todayDate);
        }).isNotEmpty
        ? _adherenceHistory.where((record) {
            final recordDate = DateTime(
              record.date.year,
              record.date.month,
              record.date.day,
            );
            return recordDate.isAtSameMomentAs(todayDate);
          }).first
        : null;

    if (todayRecord != null) {
      // Load the saved data from Firestore into the tracking maps
      setState(() {
        // Clear current tracking data
        _morningDoses.clear();
        _eveningDoses.clear();
        _nightDoses.clear();
        _reportedSideEffects.clear();

        // Load doses from saved record
        for (var entry in todayRecord.dosesToday.entries) {
          String doseKey = entry.key;
          String doseStatus = entry.value;

          // Check if the dose key contains timing information (e.g., "Rifampin_morning")
          if (doseKey.contains('_morning')) {
            String medicationName = doseKey.replaceAll('_morning', '');
            _morningDoses[medicationName] = doseStatus;
          } else if (doseKey.contains('_evening')) {
            String medicationName = doseKey.replaceAll('_evening', '');
            _eveningDoses[medicationName] = doseStatus;
          } else if (doseKey.contains('_night')) {
            String medicationName = doseKey.replaceAll('_night', '');
            _nightDoses[medicationName] = doseStatus;
          } else {
            // For backward compatibility, if no timing suffix, treat as medication name
            String medicationName = doseKey;
            // Find the medication to determine its frequency
            for (var medication in _medications) {
              if (medication.name == medicationName) {
                String frequency = medication.frequency.toLowerCase();
                if (frequency.contains('once') ||
                    frequency.contains('daily') ||
                    frequency == '1') {
                  _morningDoses[medicationName] = doseStatus;
                } else {
                  // For multiple doses, load as morning by default
                  _morningDoses[medicationName] = doseStatus;
                }
                break;
              }
            }
          }
        }

        // Load side effects
        _reportedSideEffects.addAll(todayRecord.sideEffects);

        // Load pill counts
        for (var entry in todayRecord.pillsRemaining.entries) {
          _pillCounts[entry.key] = entry.value;
        }
      });
    }
  }

  void _loadAdherenceData() {
    if (widget.patientId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Provider.of<TreatmentAdherenceProvider>(
            context,
            listen: false,
          ).loadPatientAdherence(widget.patientId!);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TreatmentAdherenceProvider>(
      builder: (context, adherenceProvider, child) {
        if (_isLoadingMedications || _isLoadingPatient || _isLoadingAdherence) {
          return Scaffold(
            backgroundColor: MadadgarTheme.backgroundColor,
            appBar: AppBar(
              title: Text('Adherence Tracking'),
              backgroundColor: MadadgarTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading patient data...'),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: MadadgarTheme.backgroundColor,
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  expandedHeight:
                      270, // Reduced since content is now more compact
                  floating: false,
                  pinned: true,
                  backgroundColor: MadadgarTheme.primaryColor,
                  iconTheme: const IconThemeData(color: Colors.white),
                  actions: [
                    IconButton(
                      onPressed: () => _viewAdherenceHistory(),
                      icon: const Icon(Icons.history),
                      tooltip: 'View History',
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: _handleMenuAction,
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'export',
                          child: Row(
                            children: [
                              const Icon(Icons.download),
                              const SizedBox(width: 8),
                              Text('Export Data', style: GoogleFonts.poppins()),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'reminders',
                          child: Row(
                            children: [
                              const Icon(Icons.notifications),
                              const SizedBox(width: 8),
                              Text(
                                'Set Reminders',
                                style: GoogleFonts.poppins(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildHeaderContent(adherenceProvider),
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(
                      48,
                    ), // Reduced height for tabs only
                    child: Container(
                      color: MadadgarTheme.primaryColor,
                      child: TabBar(
                        controller: _tabController,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        indicatorColor: Colors.white,
                        labelStyle: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        tabs: const [
                          Tab(text: 'Daily Doses'),
                          Tab(text: 'Side Effects'),
                          Tab(text: 'Pill Count'),
                          Tab(text: 'History'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              body: adherenceProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : adherenceProvider.error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${adherenceProvider.error}',
                            style: GoogleFonts.poppins(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _loadAdherenceData(),
                            child: Text('Retry', style: GoogleFonts.poppins()),
                          ),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDailyDosesTab(),
                        _buildSideEffectsTab(),
                        _buildPillCountTab(),
                        _buildHistoryTab(),
                      ],
                    ),
            ),
          ),
          floatingActionButton: _checkIfRecordedForSelectedDate()
              ? FloatingActionButton.extended(
                  onPressed: null, // Disabled when already recorded
                  backgroundColor: Colors.grey,
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: Text(
                    'Already Saved',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : FloatingActionButton.extended(
                  onPressed: () => _saveAdherenceData(adherenceProvider),
                  backgroundColor: MadadgarTheme.secondaryColor,
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: Text(
                    _isSameDay(_selectedDate, DateTime.now())
                        ? 'Save Today'
                        : 'Save for ${_formatSelectedDate()}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildHeaderContent(TreatmentAdherenceProvider provider) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            MadadgarTheme.primaryColor,
            MadadgarTheme.primaryColor.withOpacity(0.8),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            40,
            16,
            20,
          ), // Reduced top padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                height: 12,
              ), // Patient info row - make it more compact
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _patient?.name ?? 'Loading...',
                          style: GoogleFonts.poppins(
                            fontSize: 16, // Reduced from 18
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'ID: ${_patient?.patientId ?? 'N/A'}',
                          style: GoogleFonts.poppins(
                            fontSize: 10, // Reduced from 11
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Date selector - make it smaller and positioned to the right
                  Tooltip(
                    message: _getTreatmentPeriodInfo(),
                    child: GestureDetector(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isBackdatedEntry
                                  ? _formatSelectedDate()
                                  : 'Today',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white,
                              size: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12), // Compact spacing
              // Stats row
              Row(
                children: [
                  _buildHeaderStat('Today', _getTodaysDosesText()),
                  const SizedBox(width: 6),
                  _buildHeaderStat(
                    'Week',
                    '${_calculateAdherenceStats()['weekly_score']?.toStringAsFixed(0) ?? '0'}%',
                  ),
                  const SizedBox(width: 6),
                  _buildHeaderStat(
                    'Overall',
                    '${_calculateAdherenceStats()['overall_score']?.toStringAsFixed(0) ?? '0'}%',
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Treatment period - full width for better visibility
              if (_medications.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getTreatmentPeriodInfo(),
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              const SizedBox(height: 8),

              // Progress info and bar - compact version
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_getCurrentDate()} • ${_getTodayProgress().toStringAsFixed(0)}% Progress',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Progress bar
              LinearProgressIndicator(
                value: _getTodayProgress() / 100,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 4,
        ), // Reduced padding
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6), // Reduced from 8
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 11, // Reduced from 12
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 9, // Reduced from 10
                color: Colors.white.withOpacity(0.8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyDosesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Morning Doses Card - for all medications that have morning doses
          if (_morningDoses.isNotEmpty) _buildMorningDosesCard(),
          if (_morningDoses.isNotEmpty) const SizedBox(height: 16),

          // Evening Doses Card - only for twice and thrice daily medications
          if (_eveningDoses.isNotEmpty) _buildEveningDosesCard(),
          if (_eveningDoses.isNotEmpty) const SizedBox(height: 16),

          // Night Doses Card - only for thrice daily medications
          if (_nightDoses.isNotEmpty) _buildNightDosesCard(),
          if (_nightDoses.isNotEmpty) const SizedBox(height: 16),

          _buildDoseInstructionsCard(),
        ],
      ),
    );
  }

  Widget _buildSideEffectsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSideEffectsChecklistCard(),
          const SizedBox(height: 16),
          _buildSideEffectNotesCard(),
          const SizedBox(height: 16),
          _buildSideEffectsHistoryCard(),
        ],
      ),
    );
  }

  Widget _buildPillCountTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildPillCountCard(),
          const SizedBox(height: 16),
          _buildRefillAlertsCard(),
          const SizedBox(height: 16),
          _buildPillCountHistoryCard(),
        ],
      ),
    );
  }

  Widget _buildMorningDosesCard() {
    // Filter medications that should be taken in the morning
    List<Medication> morningMedications = _medications.where((medication) {
      String frequency = medication.frequency.toLowerCase();
      return frequency.contains('once') ||
          frequency.contains('daily') ||
          frequency.contains('twice') ||
          frequency.contains('thrice') ||
          frequency.contains('three') ||
          frequency == '1' ||
          frequency == '2' ||
          frequency == '3';
    }).toList();

    if (morningMedications.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wb_sunny, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Morning Doses (8:00 AM)',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ...morningMedications.map((medication) {
              return _buildDoseTrackingItem(
                medication,
                _morningDoses[medication.name] ?? '',
                (value) {
                  setState(() {
                    _morningDoses[medication.name] = value;
                  });
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEveningDosesCard() {
    // Filter medications that should be taken in the evening (twice or thrice daily)
    List<Medication> eveningMedications = _medications.where((medication) {
      String frequency = medication.frequency.toLowerCase();
      return frequency.contains('twice') ||
          frequency.contains('thrice') ||
          frequency.contains('three') ||
          frequency == '2' ||
          frequency == '3';
    }).toList();

    if (eveningMedications.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.nights_stay, color: Colors.indigo),
                const SizedBox(width: 8),
                Text(
                  'Evening Doses (8:00 PM)',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ...eveningMedications.map((medication) {
              return _buildDoseTrackingItem(
                medication,
                _eveningDoses[medication.name] ?? '',
                (value) {
                  setState(() {
                    _eveningDoses[medication.name] = value;
                  });
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildNightDosesCard() {
    // Filter medications that should be taken at night (thrice daily only)
    List<Medication> nightMedications = _medications.where((medication) {
      String frequency = medication.frequency.toLowerCase();
      return frequency.contains('thrice') ||
          frequency.contains('three') ||
          frequency == '3';
    }).toList();

    if (nightMedications.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bedtime, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Night Doses (11:00 PM)',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ...nightMedications.map((medication) {
              return _buildDoseTrackingItem(
                medication,
                _nightDoses[medication.name] ?? '',
                (value) {
                  setState(() {
                    _nightDoses[medication.name] = value;
                  });
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    // Create combined history list with today's data
    List<Map<String, dynamic>> combinedHistory = [];
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Check if today's data is already recorded
    bool todayRecorded = _adherenceHistory.any((record) {
      final recordDate = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      return recordDate.isAtSameMomentAs(todayDate);
    });

    // Add today's data (either recorded or current tracking)
    if (!todayRecorded) {
      // Add current tracking data for today
      Map<String, String> todaysDoses = {};

      // Add morning doses with timing suffix
      for (var entry in _morningDoses.entries) {
        if (entry.value.isNotEmpty) {
          todaysDoses['${entry.key}_morning'] = entry.value;
        }
      }

      // Add evening doses with timing suffix
      for (var entry in _eveningDoses.entries) {
        if (entry.value.isNotEmpty) {
          todaysDoses['${entry.key}_evening'] = entry.value;
        }
      }

      // Add night doses with timing suffix
      for (var entry in _nightDoses.entries) {
        if (entry.value.isNotEmpty) {
          todaysDoses['${entry.key}_night'] = entry.value;
        }
      }

      if (todaysDoses.isNotEmpty) {
        int takenCount = todaysDoses.values
            .where((dose) => dose == 'taken')
            .length;
        double todayScore = (takenCount / todaysDoses.length) * 100;

        combinedHistory.add({
          'date': 'Today (Live)',
          'score': todayScore,
          'doses': todaysDoses,
          'sideEffects': _reportedSideEffects,
          'isLive': true,
        });
      }
    }

    // Add historical records
    for (var record in _adherenceHistory) {
      final recordDate = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      String dateLabel = recordDate.isAtSameMomentAs(todayDate)
          ? 'Today (Saved)'
          : _formatDate(record.date);

      combinedHistory.add({
        'date': dateLabel,
        'score': record.adherenceScore,
        'doses': record.dosesToday,
        'sideEffects': record.sideEffects,
        'isLive': false,
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Adherence History',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  combinedHistory.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.grey.shade600),
                              const SizedBox(width: 8),
                              Text(
                                'No adherence history available',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: combinedHistory.length,
                          itemBuilder: (context, index) {
                            final historyItem = combinedHistory[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ExpansionTile(
                                leading: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (historyItem['isLive'] == true)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          'LIVE',
                                          style: GoogleFonts.poppins(
                                            fontSize: 8,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      historyItem['score'] >= 80
                                          ? Icons.check_circle
                                          : historyItem['score'] >= 60
                                          ? Icons.warning
                                          : Icons.error,
                                      color: historyItem['score'] >= 80
                                          ? Colors.green
                                          : historyItem['score'] >= 60
                                          ? Colors.orange
                                          : Colors.red,
                                    ),
                                  ],
                                ),
                                title: Text(
                                  'Date: ${historyItem['date']}',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  'Adherence Score: ${historyItem['score'].toStringAsFixed(0)}%\n'
                                  'Doses: ${historyItem['doses'].values.where((dose) => dose == 'taken').length}/${historyItem['doses'].length} taken',
                                  style: GoogleFonts.poppins(fontSize: 12),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Dose Details
                                        Text(
                                          'Dose Details:',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ...historyItem['doses'].entries.map<
                                          Widget
                                        >((entry) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 2,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: _getDoseStatusColor(
                                                      entry.value,
                                                    ),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    '${entry.key}: ${entry.value}',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),

                                        // Side Effects
                                        if (historyItem['sideEffects']
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Text(
                                            'Side Effects:',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            historyItem['sideEffects']
                                                .map(_formatSideEffect)
                                                .join(', '),
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ] else ...[
                                          const SizedBox(height: 12),
                                          Text(
                                            'Side Effects: None reported',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoseTrackingItem(
    Medication medication,
    String selectedStatus,
    Function(String) onStatusChanged,
  ) {
    // Assign colors based on medication name for visual distinction
    Color medicationColor = _getMedicationColor(medication.name);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: medicationColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medication.name,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '${medication.dosage} • ${medication.frequency}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (selectedStatus.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getDoseStatusColor(selectedStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    selectedStatus.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: _getDoseStatusColor(selectedStatus),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Dose status buttons
          Row(
            children: _doseOptions.map((option) {
              bool isSelected = selectedStatus == option;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ElevatedButton(
                    onPressed: () => onStatusChanged(option),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected
                          ? _getDoseStatusColor(option)
                          : Colors.grey.shade200,
                      foregroundColor: isSelected
                          ? Colors.white
                          : Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(_getDoseStatusIcon(option), size: 16),
                        Text(
                          _formatDoseOption(option),
                          style: GoogleFonts.poppins(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDoseInstructionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: MadadgarTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Dosing Instructions',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildInstructionItem(
              Icons.restaurant,
              'Take with food',
              'All medications should be taken with breakfast',
            ),
            _buildInstructionItem(
              Icons.schedule,
              'Same time daily',
              'Take at 8:00 AM every day for best results',
            ),
            _buildInstructionItem(
              Icons.warning,
              'If you vomit',
              'Contact your CHW immediately if you vomit within 1 hour',
            ),
            _buildInstructionItem(
              Icons.help,
              'Missed dose',
              'Take as soon as you remember, but don\'t double dose',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideEffectsChecklistCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Side Effects Today',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              'Check any side effects you experienced today:',
              style: GoogleFonts.poppins(color: Colors.black87),
            ),
            const SizedBox(height: 12),

            ..._sideEffectsList.map((effect) {
              return CheckboxListTile(
                title: Text(
                  _formatSideEffect(effect),
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                value: _reportedSideEffects.contains(effect),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _reportedSideEffects.add(effect);
                    } else {
                      _reportedSideEffects.remove(effect);
                    }
                  });
                },
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSideEffectNotesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Additional Notes',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              decoration: InputDecoration(
                labelText: 'Describe any side effects in detail',
                labelStyle: GoogleFonts.poppins(),
                hintText: 'How severe? When did it start? Any other details...',
                hintStyle: GoogleFonts.poppins(color: Colors.grey),
                border: const OutlineInputBorder(),
              ),
              style: GoogleFonts.poppins(),
              maxLines: 3,
              onChanged: (value) => _sideEffectNotes = value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideEffectsHistoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Side Effects',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            ..._getRecentSideEffects().map((effect) {
              return _buildSideEffectHistoryItem(
                effect['date'],
                effect['effects'],
                effect['severity'],
              );
            }).toList(),

            if (_getRecentSideEffects().isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'No recent side effects recorded',
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillCountCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medication, color: MadadgarTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Current Pill Count',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ..._medications.map((medication) {
              return _buildPillCountItem(medication);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRefillAlertsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Medication Status',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Show low stock medications without refill option
            ..._medications
                .where((med) => (_pillCounts[med.name] ?? 0) <= 10)
                .map((medication) {
                  int currentCount = _pillCounts[medication.name] ?? 0;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${medication.name}: $currentCount pills remaining',
                            style: GoogleFonts.poppins(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                })
                .toList(),

            // Show message if all medications have sufficient supply
            if (_medications.every((med) => (_pillCounts[med.name] ?? 0) > 10))
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'All medications have sufficient supply',
                        style: GoogleFonts.poppins(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillCountHistoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pill Count History',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            ..._getPillCountHistory().map((history) {
              return _buildPillCountHistoryItem(
                history['date'],
                history['count'],
                history['status'],
              );
            }).toList(),

            if (_getPillCountHistory().isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'No pill count history available',
                      style: GoogleFonts.poppins(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(
    IconData icon,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: MadadgarTheme.primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideEffectHistoryItem(
    String date,
    List<String> effects,
    String severity,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              date,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              effects.isEmpty
                  ? 'No side effects'
                  : effects.map(_formatSideEffect).join(', '),
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getSeverityColor(severity).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              severity,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: _getSeverityColor(severity),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillCountItem(Medication medication) {
    int currentCount = _pillCounts[medication.name] ?? 0;
    int daysRemaining = currentCount;
    bool needsRefill = daysRemaining <= 10;
    Color medicationColor = _getMedicationColor(medication.name);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: needsRefill
            ? Colors.orange.withOpacity(0.1)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: needsRefill
              ? Colors.orange.withOpacity(0.3)
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: medicationColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication.name,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                Text(
                  '$currentCount pills remaining ($daysRemaining days)',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: needsRefill
                        ? Colors.orange.shade700
                        : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => _adjustPillCount(medication.name, -1),
                icon: const Icon(Icons.remove_circle_outline),
                iconSize: 20,
              ),
              SizedBox(
                width: 40,
                child: TextFormField(
                  initialValue: currentCount.toString(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    int? newCount = int.tryParse(value);
                    if (newCount != null) {
                      setState(() {
                        _pillCounts[medication.name] = newCount;
                      });
                    }
                  },
                ),
              ),
              IconButton(
                onPressed: () => _adjustPillCount(medication.name, 1),
                icon: const Icon(Icons.add_circle_outline),
                iconSize: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillCountHistoryItem(String date, String count, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              date,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(count, style: GoogleFonts.poppins(fontSize: 12)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              status,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: _getStatusColor(status),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final months = [
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
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  double _getTodayProgress() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Check if today's adherence has been recorded
    TreatmentAdherence? todayRecord =
        _adherenceHistory.where((record) {
          final recordDate = DateTime(
            record.date.year,
            record.date.month,
            record.date.day,
          );
          return recordDate.isAtSameMomentAs(todayDate);
        }).isNotEmpty
        ? _adherenceHistory.where((record) {
            final recordDate = DateTime(
              record.date.year,
              record.date.month,
              record.date.day,
            );
            return recordDate.isAtSameMomentAs(todayDate);
          }).first
        : null;

    if (todayRecord != null) {
      // Use recorded data for today
      int totalDoses = todayRecord.dosesToday.length;
      int completedDoses = todayRecord.dosesToday.values
          .where((status) => status == 'taken')
          .length;
      return totalDoses > 0 ? (completedDoses / totalDoses) * 100 : 0;
    } else {
      // Use current tracking data for today
      Map<String, String> allTodaysDoses = {};

      // Add morning doses with timing suffix
      for (var entry in _morningDoses.entries) {
        if (entry.value.isNotEmpty) {
          allTodaysDoses['${entry.key}_morning'] = entry.value;
        }
      }

      // Add evening doses with timing suffix
      for (var entry in _eveningDoses.entries) {
        if (entry.value.isNotEmpty) {
          allTodaysDoses['${entry.key}_evening'] = entry.value;
        }
      }

      // Add night doses with timing suffix
      for (var entry in _nightDoses.entries) {
        if (entry.value.isNotEmpty) {
          allTodaysDoses['${entry.key}_night'] = entry.value;
        }
      }

      int totalDoses = allTodaysDoses.length;
      int completedDoses = allTodaysDoses.values
          .where((status) => status == 'taken')
          .length;
      return totalDoses > 0 ? (completedDoses / totalDoses) * 100 : 0;
    }
  }

  Color _getDoseStatusColor(String status) {
    switch (status) {
      case 'taken':
        return Colors.green;
      case 'missed':
        return Colors.red;
      case 'late':
        return Colors.orange;
      case 'vomited':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getDoseStatusIcon(String status) {
    switch (status) {
      case 'taken':
        return Icons.check_circle;
      case 'missed':
        return Icons.cancel;
      case 'late':
        return Icons.access_time;
      case 'vomited':
        return Icons.warning;
      default:
        return Icons.help;
    }
  }

  String _formatDoseOption(String option) {
    switch (option) {
      case 'taken':
        return 'Taken';
      case 'missed':
        return 'Missed';
      case 'late':
        return 'Late';
      case 'vomited':
        return 'Vomited';
      default:
        return option;
    }
  }

  String _formatSideEffect(String effect) {
    switch (effect) {
      case 'nausea':
        return 'Nausea';
      case 'vomiting':
        return 'Vomiting';
      case 'rash':
        return 'Skin Rash';
      case 'dizziness':
        return 'Dizziness';
      case 'hearing_problems':
        return 'Hearing Problems';
      case 'joint_pain':
        return 'Joint Pain';
      case 'vision_changes':
        return 'Vision Changes';
      default:
        return effect;
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'mild':
        return Colors.green;
      case 'moderate':
        return Colors.orange;
      case 'severe':
        return Colors.red;
      case 'none':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'on track':
        return Colors.green;
      case 'missed dose':
        return Colors.orange;
      case 'refill needed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _adjustPillCount(String medicationName, int adjustment) {
    setState(() {
      int currentCount = _pillCounts[medicationName] ?? 0;
      int newCount = currentCount + adjustment;
      if (newCount >= 0) {
        _pillCounts[medicationName] = newCount;
      }
    });
  }

  String _getTodaysDosesText() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Check if today's adherence has been recorded
    TreatmentAdherence? todayRecord =
        _adherenceHistory.where((record) {
          final recordDate = DateTime(
            record.date.year,
            record.date.month,
            record.date.day,
          );
          return recordDate.isAtSameMomentAs(todayDate);
        }).isNotEmpty
        ? _adherenceHistory.where((record) {
            final recordDate = DateTime(
              record.date.year,
              record.date.month,
              record.date.day,
            );
            return recordDate.isAtSameMomentAs(todayDate);
          }).first
        : null;

    if (todayRecord != null) {
      // Use recorded data
      int totalDoses = todayRecord.dosesToday.length;
      int takenDoses = todayRecord.dosesToday.values
          .where((status) => status == 'taken')
          .length;
      return '$takenDoses/$totalDoses ✓';
    } else {
      // Use current tracking data
      Map<String, String> allTodaysDoses = {};

      // Add morning doses with timing suffix
      for (var entry in _morningDoses.entries) {
        if (entry.value.isNotEmpty) {
          allTodaysDoses['${entry.key}_morning'] = entry.value;
        }
      }

      // Add evening doses with timing suffix
      for (var entry in _eveningDoses.entries) {
        if (entry.value.isNotEmpty) {
          allTodaysDoses['${entry.key}_evening'] = entry.value;
        }
      }

      // Add night doses with timing suffix
      for (var entry in _nightDoses.entries) {
        if (entry.value.isNotEmpty) {
          allTodaysDoses['${entry.key}_night'] = entry.value;
        }
      }

      int totalDoses = allTodaysDoses.length;
      int takenDoses = allTodaysDoses.values
          .where((status) => status == 'taken')
          .length;

      return totalDoses > 0 ? '$takenDoses/$totalDoses' : '0/0';
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'export':
        _exportAdherenceData();
        break;
      case 'reminders':
        _setReminders();
        break;
    }
  }

  void _viewAdherenceHistory() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Adherence history feature coming soon!',
          style: GoogleFonts.poppins(),
        ),
      ),
    );
  }

  void _exportAdherenceData() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Export feature coming soon!',
          style: GoogleFonts.poppins(),
        ),
      ),
    );
  }

  void _setReminders() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reminder settings feature coming soon!',
          style: GoogleFonts.poppins(),
        ),
      ),
    );
  }

  Future<void> _saveAdherenceData(TreatmentAdherenceProvider provider) async {
    // Validate that the selected date is within the treatment period
    if (!_isValidTreatmentDate(_selectedDate)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot save adherence data for ${_formatSelectedDate()}. Date is outside the treatment period.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'View Period',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _getTreatmentPeriodInfo(),
                      style: GoogleFonts.poppins(),
                    ),
                    backgroundColor: Colors.blue,
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
            ),
          ),
        );
      }
      return;
    }

    // Check if the selected date's adherence has already been recorded
    if (_checkIfRecordedForSelectedDate()) {
      if (mounted) {
        final isToday = _isSameDay(_selectedDate, DateTime.now());
        final dateText = isToday ? 'Today\'s' : '${_formatSelectedDate()}\'s';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$dateText adherence has already been recorded. Data cannot be entered twice for the same day.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (widget.patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Patient ID not found', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Combine all dose tracking data with timing information
    Map<String, String> allDoses = {};

    // Add morning doses with suffix
    for (var entry in _morningDoses.entries) {
      if (entry.value.isNotEmpty) {
        allDoses['${entry.key}_morning'] = entry.value;
      }
    }

    // Add evening doses with suffix
    for (var entry in _eveningDoses.entries) {
      if (entry.value.isNotEmpty) {
        allDoses['${entry.key}_evening'] = entry.value;
      }
    }

    // Add night doses with suffix
    for (var entry in _nightDoses.entries) {
      if (entry.value.isNotEmpty) {
        allDoses['${entry.key}_night'] = entry.value;
      }
    }

    // Validate that at least one dose has been tracked
    if (allDoses.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please track at least one dose before saving adherence data',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      await provider.recordAdherence(
        patientId: widget.patientId!,
        dosesToday: allDoses,
        sideEffects: _reportedSideEffects,
        pillsRemaining: Map<String, int>.from(
          _pillCounts,
        ), // Convert to Map<String, int>
        counselingGiven: true, // Assuming counseling is always given
        notes: 'Adherence recorded via CHW mobile app',
        recordDate: _selectedDate, // Pass the selected date to the provider
      );

      // Reload adherence history to include the new record
      await _loadAdherenceHistory();

      if (mounted) {
        final isToday = _isSameDay(_selectedDate, DateTime.now());
        final dateText = isToday ? 'Today\'s' : '${_formatSelectedDate()}\'s';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$dateText adherence data saved successfully!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save adherence data: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
