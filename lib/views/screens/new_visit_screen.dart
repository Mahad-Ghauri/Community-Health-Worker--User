import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:chw_tb/config/theme.dart';
import 'package:chw_tb/controllers/providers/patient_provider.dart';
import 'package:chw_tb/controllers/services/gps_service.dart';
import 'package:chw_tb/models/core_models.dart';

class NewVisitScreen extends StatefulWidget {
  const NewVisitScreen({super.key});

  @override
  State<NewVisitScreen> createState() => _NewVisitScreenState();
}

class _NewVisitScreenState extends State<NewVisitScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();

  bool _isLoading = false;
  bool _gpsEnabled = false;
  bool _patientFound = true;
  String? _selectedPatientId;
  Patient? _selectedPatient;
  String _selectedVisitType = 'home_visit';
  final List<String> _capturedPhotos = [];
  Map<String, double>? _currentLocation;
  bool? _locationValidated;
  double? _distanceFromPatient;
  double? _gpsAccuracy;
  String? _gpsStatusMessage;

  final List<Map<String, String>> _visitTypes = [
    {'value': 'home_visit', 'label': 'Home Visit'},
    {'value': 'follow_up', 'label': 'Follow-up Visit'},
    {'value': 'tracing', 'label': 'Contact Tracing'},
    {'value': 'medicine_delivery', 'label': 'Medicine Delivery'},
    {'value': 'counseling', 'label': 'Counseling Session'},
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
    _fadeController.forward();
    _loadInitialData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get patient ID from route arguments if navigated from patient details
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null &&
        args is Map<String, dynamic> &&
        args['patientId'] != null) {
      _selectedPatientId = args['patientId'];
      _loadSelectedPatient();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    // Load patients for selection
    final patientProvider = Provider.of<PatientProvider>(
      context,
      listen: false,
    );
    await patientProvider.loadPatients();

    setState(() => _isLoading = false);
  }

  Future<void> _loadSelectedPatient() async {
    if (_selectedPatientId != null) {
      final patientProvider = Provider.of<PatientProvider>(
        context,
        listen: false,
      );
      await patientProvider.selectPatient(_selectedPatientId!);
      setState(() {
        _selectedPatient = patientProvider.selectedPatient;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  IconData _getVisitTypeIcon(String type) {
    switch (type) {
      case 'home_visit':
        return Icons.home;
      case 'follow_up':
        return Icons.schedule;
      case 'tracing':
        return Icons.search;
      case 'medicine_delivery':
        return Icons.medication;
      case 'counseling':
        return Icons.psychology;
      default:
        return Icons.home;
    }
  }

  void _submitVisit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPatient == null) {
      _showSnackBar('Please select a patient', isError: true);
      return;
    }

    if (_selectedVisitType.isEmpty) {
      _showSnackBar('Please select visit type', isError: true);
      return;
    }

    if (!_gpsEnabled || _currentLocation == null) {
      _showSnackBar('Please capture GPS location before submitting visit', isError: true);
      return;
    }

    // Block submission if location validation failed
    if (_locationValidated == false) {
      _showSnackBar(
        'Visit cannot be logged: You must be within 35 meters of the patient location. Current distance: ${_distanceFromPatient?.toStringAsFixed(1)}m',
        isError: true,
      );
      return;
    }

    // Ensure location is validated for patients with GPS data
    if (_selectedPatient!.gpsLocation.isNotEmpty && _locationValidated == null) {
      _showSnackBar('Please wait for location validation to complete', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final visitProvider = Provider.of<VisitProvider>(context, listen: false);

      final visitId = await visitProvider.createVisit(
        patientId: _selectedPatient!.patientId,
        visitType: _selectedVisitType,
        found: _patientFound,
        notes: _notesController.text.trim(),
        photos: _capturedPhotos.isNotEmpty ? _capturedPhotos : null,
      );
      
      // Check if there's an error in the visit provider
      if (visitProvider.error != null) {
        String errorMessage = visitProvider.error!;
        
        // Make the 2-hour restriction message more user-friendly
        if (errorMessage.contains('Recent visit already exists')) {
          errorMessage = 'You cannot create another visit for this patient yet. Please wait at least 2 hours between visits for the same patient.';
        }
        
        _showSnackBar(errorMessage, isError: true);
        return;
      }

      if (visitId != null && mounted) {
        _showSnackBar('Visit recorded successfully!');
        
        // Only navigate to adherence tracking if patient was found
        if (_patientFound) {
          Navigator.pushReplacementNamed(
            context,
            '/adherence-tracking',
            arguments: {'patientId': _selectedPatient!.patientId},
          );
        } else {
          // Patient not found - return to previous screen
          Navigator.pop(context);
        }
      } else {
        _showSnackBar('Failed to record visit - please try again', isError: true);
      }
    } catch (e) {
      String errorMessage = e.toString();
      
      // Handle specific error cases with user-friendly messages
      if (errorMessage.contains('2 hours') || errorMessage.contains('wait at least')) {
        errorMessage = 'Cannot create visit: You must wait at least 2 hours between visits for the same patient. This prevents duplicate entries.';
      } else if (errorMessage.contains('not authenticated')) {
        errorMessage = 'Authentication error: Please log in again.';
      } else if (errorMessage.contains('GPS') || errorMessage.contains('location')) {
        errorMessage = 'Location error: Please ensure GPS is enabled and try again.';
      } else if (errorMessage.contains('network') || errorMessage.contains('connection')) {
        errorMessage = 'Network error: Please check your internet connection and try again.';
      } else {
        // Clean up the error message by removing "Exception: " prefix
        errorMessage = errorMessage.replaceFirst('Exception: ', '');
      }
      
      _showSnackBar(errorMessage, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: isError ? MadadgarTheme.errorColor : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MadadgarTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'New Visit',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: MadadgarTheme.primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_gpsEnabled)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.gps_fixed,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'GPS',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient selection section
                _buildPatientSelectionSection(),

                const SizedBox(height: 24),

                // Visit type selection
                _buildVisitTypeSection(),

                const SizedBox(height: 24),

                // GPS location section
                _buildGPSSection(),

                const SizedBox(height: 24),

                // Patient found toggle
                _buildPatientFoundSection(),

                const SizedBox(height: 24),

                // Visit notes
                _buildNotesSection(),

                const SizedBox(height: 24),

                // Photo capture section
                _buildPhotoSection(),

                const SizedBox(height: 32),

                // Submit button
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientSelectionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient Selection',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            // Patient dropdown or selected patient display
            if (_selectedPatient == null) ...[
              Consumer<PatientProvider>(
                builder: (context, patientProvider, child) {
                  final patients = patientProvider.filteredPatients;

                  return DropdownButtonFormField<Patient>(
                    decoration: InputDecoration(
                      labelText: 'Select Patient',
                      hintText: 'Choose a patient...',
                      prefixIcon: Icon(
                        Icons.person,
                        color: MadadgarTheme.primaryColor,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: MadadgarTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                    initialValue: _selectedPatient,
                    isExpanded: true, // ✅ Prevents overflow
                    items: patients.map((patient) {
                      return DropdownMenuItem<Patient>(
                        value: patient,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              patient.name,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'ID: ${patient.patientId} • ${patient.phone}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (Patient? patient) {
                      setState(() {
                        _selectedPatient = patient;
                        _selectedPatientId = patient?.patientId;
                        // Reset validation when patient changes
                        _locationValidated = null;
                        _distanceFromPatient = null;
                      });
                      
                      // Re-validate location if GPS is already captured
                      if (_gpsEnabled && _currentLocation != null && patient != null) {
                        _validateLocation();
                      }
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select a patient';
                      }
                      return null;
                    },
                  );
                },
              ),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MadadgarTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: MadadgarTheme.primaryColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: MadadgarTheme.primaryColor,
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedPatient!.name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'ID: ${_selectedPatient!.patientId} • ${_selectedPatient!.phone}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle, color: Colors.green),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVisitTypeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Visit Type',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
              ),
              itemCount: _visitTypes.length,
              itemBuilder: (context, index) {
                final type = _visitTypes[index];
                final isSelected = _selectedVisitType == type['value'];

                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedVisitType = type['value']!),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? MadadgarTheme.primaryColor.withOpacity(0.1)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? MadadgarTheme.primaryColor
                            : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getVisitTypeIcon(type['value']!),
                          color: isSelected
                              ? MadadgarTheme.primaryColor
                              : Colors.grey.shade600,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          type['label']!,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? MadadgarTheme.primaryColor
                                : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGPSSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: MadadgarTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'GPS Location Verification',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // GPS Status Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main status
                      Text(
                        _gpsEnabled ? 'Location Captured' : 'Location Required',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _gpsEnabled
                              ? Colors.green
                              : Colors.orange.shade700,
                        ),
                      ),
                      
                      // Status message
                      if (_gpsStatusMessage != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _gpsStatusMessage!,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _captureGPS,
                  icon: _isLoading 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(_gpsEnabled ? Icons.refresh : Icons.gps_fixed),
                  label: Text(
                    _isLoading ? 'Capturing...' : (_gpsEnabled ? 'Refresh' : 'Capture'),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gpsEnabled
                        ? Colors.green
                        : MadadgarTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),

            // GPS Details (when captured)
            if (_gpsEnabled && _currentLocation != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // GPS Accuracy
                    Row(
                      children: [
                        Icon(Icons.my_location, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Accuracy: ${_gpsAccuracy?.toStringAsFixed(1)}m (${_getAccuracyDescription(_gpsAccuracy ?? 0)})',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    // Location validation status
                    if (_selectedPatient != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _locationValidated == true 
                                ? Icons.check_circle 
                                : _locationValidated == false 
                                    ? Icons.warning 
                                    : Icons.info,
                            size: 16,
                            color: _locationValidated == true 
                                ? Colors.green 
                                : _locationValidated == false 
                                    ? Colors.orange 
                                    : Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _distanceFromPatient != null
                                  ? 'Distance from patient: ${_distanceFromPatient!.toStringAsFixed(1)}m'
                                  : 'Patient location validation pending',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Coordinates (for debugging)
                    const SizedBox(height: 8),
                    Text(
                      'Coordinates: ${_currentLocation!['lat']!.toStringAsFixed(6)}, ${_currentLocation!['lng']!.toStringAsFixed(6)}',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Warning for location validation
            if (_locationValidated == false) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You appear to be outside the patient\'s location area. Please ensure you are at the correct address.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPatientFoundSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient Status',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _patientFound = true),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _patientFound
                            ? Colors.green.withOpacity(0.1)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _patientFound
                              ? Colors.green
                              : Colors.grey.shade300,
                          width: _patientFound ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: _patientFound ? Colors.green : Colors.grey,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Patient Found',
                            style: GoogleFonts.poppins(
                              fontWeight: _patientFound
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: _patientFound
                                  ? Colors.green
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _patientFound = false),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: !_patientFound
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: !_patientFound
                              ? Colors.orange
                              : Colors.grey.shade300,
                          width: !_patientFound ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.cancel,
                            color: !_patientFound ? Colors.orange : Colors.grey,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Patient Not Found',
                            style: GoogleFonts.poppins(
                              fontWeight: !_patientFound
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: !_patientFound
                                  ? Colors.orange
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Visit Notes',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'Enter visit details, observations, and notes...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: MadadgarTheme.primaryColor,
                    width: 2,
                  ),
                ),
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please add visit notes';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.camera_alt, color: MadadgarTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Visit Documentation',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_capturedPhotos.isNotEmpty) ...[
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _capturedPhotos.length,
                  itemBuilder: (context, index) => Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Icon(
                            Icons.image,
                            color: Colors.grey.shade600,
                            size: 40,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _capturedPhotos.removeAt(index)),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _capturePhoto,
                icon: const Icon(Icons.camera_alt),
                label: Text(
                  _capturedPhotos.isEmpty
                      ? 'Capture Photo'
                      : 'Add Another Photo',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: BorderSide(color: MadadgarTheme.primaryColor),
                  foregroundColor: MadadgarTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Column(
      children: [
        // Status indicator
        if (!_patientFound) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Patient not found - Visit will be logged without adherence tracking',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Timing restriction info
        if (_selectedPatient != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Note: Only one visit per patient every 2 hours is allowed to prevent duplicates',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitVisit,
            style: ElevatedButton.styleFrom(
              backgroundColor: MadadgarTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _patientFound ? 'Log Visit & Track Adherence' : 'Log Visit Only',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  void _captureGPS() async {
    setState(() {
      _isLoading = true;
      _gpsStatusMessage = 'Capturing GPS location...';
    });

    try {
      final gpsService = GPSService();
      
      // Get current location with high accuracy
      final location = await gpsService.getCurrentLocationWithRetry();
      
      setState(() {
        _currentLocation = location;
        _gpsAccuracy = location['accuracy'];
        _gpsEnabled = true;
        _gpsStatusMessage = 'GPS location captured successfully';
      });

      // If patient is selected, validate location
      if (_selectedPatient != null) {
        await _validateLocation();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'GPS location captured with ${_getAccuracyDescription(_gpsAccuracy!)} accuracy',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _gpsEnabled = false;
        _gpsStatusMessage = 'Failed to capture GPS: $e';
        _locationValidated = null;
        _distanceFromPatient = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to capture GPS location: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _validateLocation() async {
    if (_currentLocation == null || _selectedPatient == null) return;

    try {
      // Get patient location from Firestore
      final patientLocation = _selectedPatient!.gpsLocation;
      
      if (patientLocation.isEmpty) {
        setState(() {
          _locationValidated = null;
          _distanceFromPatient = null;
          _gpsStatusMessage = 'Patient location not available - validation skipped';
        });
        return;
      }

      final gpsService = GPSService();
      
      // Calculate distance
      final distance = gpsService.calculateDistance(
        lat1: _currentLocation!['lat']!,
        lng1: _currentLocation!['lng']!,
        lat2: patientLocation['lat']!,
        lng2: patientLocation['lng']!,
      );

      // Validate if within allowed radius (35m)
      final isValid = distance <= 35.0;

      setState(() {
        _distanceFromPatient = distance;
        _locationValidated = isValid;
        _gpsStatusMessage = isValid
            ? 'Location verified - ${distance.toStringAsFixed(1)}m from patient'
            : 'Invalid location: ${distance.toStringAsFixed(1)}m from patient (>35m limit)';
      });
    } catch (e) {
      setState(() {
        _locationValidated = null;
        _distanceFromPatient = null;
        _gpsStatusMessage = 'Location validation failed: $e';
      });
    }
  }

  String _getAccuracyDescription(double accuracy) {
    if (accuracy <= 5) return 'Excellent';
    if (accuracy <= 10) return 'Good';
    if (accuracy <= 20) return 'Fair';
    if (accuracy <= 50) return 'Poor';
    return 'Very Poor';
  }

  void _capturePhoto() {
    setState(() {
      _capturedPhotos.add('photo_${_capturedPhotos.length + 1}.jpg');
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Photo captured', style: GoogleFonts.poppins()),
        backgroundColor: Colors.green,
      ),
    );
  }
}
