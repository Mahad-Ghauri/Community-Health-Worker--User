// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chw_tb/config/theme.dart';
import 'package:provider/provider.dart';
import 'package:chw_tb/controllers/providers/patient_provider.dart';
import 'package:chw_tb/controllers/services/gps_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterPatientScreen extends StatefulWidget {
  const RegisterPatientScreen({super.key});

  @override
  State<RegisterPatientScreen> createState() => _RegisterPatientScreenState();
}

class _RegisterPatientScreenState extends State<RegisterPatientScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();

  int _currentStep = 0;
  bool _isLoading = false;
  bool _gpsEnabled = false;
  bool _consentGiven = false;

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  String _selectedGender = '';
  String _selectedTbStatus = '';
  String _selectedFacility = '';
  DateTime? _diagnosisDate;
  Map<String, double>? _currentLocation;
  List<Map<String, dynamic>> _facilities = [];

  final List<String> _genderOptions = ['Male', 'Female', 'Other'];
  final List<String> _tbStatusOptions = [
    'newly_diagnosed',
    'on_treatment',
    'relapse',
    'treatment_after_failure',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _fadeController.forward();

    _loadFacilities();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadFacilities() async {
    try {
      setState(() => _isLoading = true);
      
      // Load facilities from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('facilities')
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      final facilities = <Map<String, dynamic>>[];
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        facilities.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Facility',
          'type': data['type'] ?? 'clinic',
          'address': data['address'] ?? '',
          'contact': data['contact'] ?? {},
          'services': data['services'] ?? [],
        });
      }

      setState(() {
        _facilities = facilities;
        _isLoading = false;
      });

      if (facilities.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No facilities found. Please contact your administrator to add facilities.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        String errorMessage = 'Unable to load facilities';
        
        // Provide user-friendly error messages
        if (e.toString().contains('permission')) {
          errorMessage = 'You do not have permission to view facilities. Please contact your administrator.';
        } else if (e.toString().contains('network') || e.toString().contains('connection')) {
          errorMessage = 'Network error: Please check your internet connection and try again.';
        } else if (e.toString().contains('timeout')) {
          errorMessage = 'Request timed out. Please try again.';
        } else {
          errorMessage = 'Failed to load facilities. Please try again or contact support if the problem persists.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage, style: GoogleFonts.poppins()),
            backgroundColor: MadadgarTheme.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final gpsService = GPSService();
      final location = await gpsService.getCurrentLocation();
      setState(() {
        _currentLocation = location;
        _gpsEnabled = true;
      });
    } catch (e) {
      setState(() {
        _gpsEnabled = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GPS Error: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _registerPatient() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient consent is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final patientProvider = context.read<PatientProvider>();

      final patientId = await patientProvider.registerPatient(
        name: _nameController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        gender: _selectedGender,
        tbStatus: _selectedTbStatus,
        treatmentFacility: _selectedFacility,
        consent: _consentGiven,
        consentSignature: 'Digital consent given during registration',
        diagnosisDate: _diagnosisDate,
      );

      if (mounted && patientId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Patient registered successfully! ID: $patientId'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to patient list
        Navigator.pushReplacementNamed(context, '/patients');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
            backgroundColor: MadadgarTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  final List<FormStep> _formSteps = [
    FormStep(
      title: 'Personal Details',
      icon: Icons.person_outline,
      description: 'Basic patient information',
    ),
    FormStep(
      title: 'Medical Information',
      icon: Icons.medical_information_outlined,
      description: 'TB status and treatment details',
    ),
    FormStep(
      title: 'Location & Consent',
      icon: Icons.location_on_outlined,
      description: 'GPS location and consent forms',
    ),
  ];

  void _nextStep() {
    if (_currentStep < _formSteps.length - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MadadgarTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Register Patient',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: MadadgarTheme.primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(),

            // Form content
            Expanded(
              child: Form(
                key: _formKey,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) =>
                      setState(() => _currentStep = index),
                  itemCount: _formSteps.length,
                  itemBuilder: (context, index) => _buildStepContent(index),
                ),
              ),
            ),

            // Navigation buttons
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      color: MadadgarTheme.primaryColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: List.generate(_formSteps.length, (index) {
              final isActive = index == _currentStep;
              final isCompleted = index < _currentStep;

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    right: index < _formSteps.length - 1 ? 8 : 0,
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: isCompleted || isActive
                              ? Colors.white
                              : Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          isCompleted ? Icons.check : _formSteps[index].icon,
                          color: isCompleted || isActive
                              ? MadadgarTheme.primaryColor
                              : Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formSteps[index].title,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: isActive
                              ? Colors.white
                              : Colors.white.withOpacity(0.7),
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (_currentStep + 1) / _formSteps.length,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(int stepIndex) {
    switch (stepIndex) {
      case 0:
        return _buildPersonalDetailsStep();
      case 1:
        return _buildMedicalInfoStep();
      case 2:
        return _buildLocationConsentStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPersonalDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Details',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter basic patient information',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 32),

          _buildTextField(
            controller: _nameController,
            label: 'Full Name *',
            hint: 'Enter patient full name',
            icon: Icons.person_outline,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(
                  controller: _ageController,
                  label: 'Age *',
                  hint: 'Enter',
                  icon: Icons.calendar_today,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Age is required';
                    }
                    final age = int.tryParse(value);
                    if (age == null || age < 0 || age > 120) {
                      return 'Enter valid age';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: _buildDropdownField(
                  label: 'Gender *',
                  value: _selectedGender,
                  items: _genderOptions,
                  onChanged: (value) =>
                      setState(() => _selectedGender = value!),
                  icon: Icons.person,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _buildTextField(
            controller: _phoneController,
            label: 'Phone Number',
            hint: 'Enter phone number',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),

          _buildTextField(
            controller: _addressController,
            label: 'Address *',
            hint: 'Enter complete address',
            icon: Icons.location_on,
            maxLines: 3,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Address is required';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Medical Information',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'TB status and treatment details',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 32),

          _buildDropdownField(
            label: 'TB Status *',
            value: _selectedTbStatus,
            items: _tbStatusOptions,
            onChanged: (value) => setState(() => _selectedTbStatus = value!),
            icon: Icons.medical_information,
          ),
          const SizedBox(height: 20),

          _buildDateField(
            label: 'Diagnosis Date',
            value: _diagnosisDate,
            onChanged: (date) => setState(() => _diagnosisDate = date),
            icon: Icons.calendar_today,
          ),
          const SizedBox(height: 20),

          _buildFacilityDropdown(),

          const SizedBox(height: 16),
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Facilities will be loaded from the database when available',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationConsentStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location & Consent',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'GPS location and patient consent',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 32),

          // GPS Location Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.gps_fixed,
                        color: _gpsEnabled ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'GPS Location',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _gpsEnabled
                        ? 'Location captured successfully'
                        : 'GPS location not captured',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: _gpsEnabled ? Colors.green : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _captureGPS,
                      icon: Icon(_gpsEnabled ? Icons.refresh : Icons.gps_fixed),
                      label: Text(
                        _gpsEnabled
                            ? 'Refresh Location'
                            : 'Capture GPS Location',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MadadgarTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Consent Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Patient Consent',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'I consent to the collection and use of my health information for TB treatment monitoring and follow-up visits by the Community Health Worker.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: _consentGiven,
                    onChanged: (value) =>
                        setState(() => _consentGiven = value!),
                    title: Text(
                      'Patient provides consent',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Required to register patient',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    activeColor: MadadgarTheme.primaryColor,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: MadadgarTheme.primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: MadadgarTheme.primaryColor, width: 2),
        ),
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  Widget _buildFacilityDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedFacility.isEmpty ? null : _selectedFacility,
      decoration: InputDecoration(
        labelText: 'Treatment Facility *',
        prefixIcon: Icon(
          Icons.local_hospital,
          color: MadadgarTheme.primaryColor,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: MadadgarTheme.primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
      ),
      hint: _isLoading 
          ? Text(
              'Loading facilities...',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            )
          : Text(
              _facilities.isEmpty ? 'No facilities available' : 'Select facility',
              style: GoogleFonts.poppins(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
      isExpanded: true,
      items: _facilities
          .map(
            (facility) => DropdownMenuItem(
              value: facility['id'] as String,
              child: Text(
                '${facility['name']} (${facility['type']})',
                style: GoogleFonts.poppins(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: _facilities.isEmpty ? null : (value) => setState(() => _selectedFacility = value!),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Treatment facility is required';
        }
        return null;
      },
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
    String? placeholder,
  }) {
    return DropdownButtonFormField<String>(
      value: value.isEmpty ? null : value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: MadadgarTheme.primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: MadadgarTheme.primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
      ),
      hint: Text(
        placeholder ?? 'Select $label',
        style: GoogleFonts.poppins(fontSize: 14),
        overflow: TextOverflow.ellipsis,
      ),
      isExpanded: true,
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: GoogleFonts.poppins(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: (value) {
        if (label.contains('*') && (value == null || value.isEmpty)) {
          return '${label.replaceAll('*', '').trim()} is required';
        }
        return null;
      },
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (date != null) {
          onChanged(date);
        }
      },
      child: AbsorbPointer(
        child: TextFormField(
          decoration: InputDecoration(
            labelText: label,
            hintText: 'Select date',
            prefixIcon: Icon(icon, color: MadadgarTheme.primaryColor),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: MadadgarTheme.primaryColor,
                width: 2,
              ),
            ),
          ),
          controller: TextEditingController(
            text: value != null
                ? '${value.day}/${value.month}/${value.year}'
                : '',
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: MadadgarTheme.primaryColor),
                ),
                child: Text(
                  'Previous',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: MadadgarTheme.primaryColor,
                  ),
                ),
              ),
            ),

          if (_currentStep > 0) const SizedBox(width: 16),

          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : (_currentStep == _formSteps.length - 1
                        ? _registerPatient
                        : _nextStep),
              style: ElevatedButton.styleFrom(
                backgroundColor: MadadgarTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _currentStep == _formSteps.length - 1
                          ? 'Register Patient'
                          : 'Next',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _captureGPS() {
    // Mock GPS capture
    setState(() => _gpsEnabled = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'GPS location captured successfully',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.green,
      ),
    );
  }
}

class FormStep {
  final String title;
  final IconData icon;
  final String description;

  FormStep({
    required this.title,
    required this.icon,
    required this.description,
  });
}
