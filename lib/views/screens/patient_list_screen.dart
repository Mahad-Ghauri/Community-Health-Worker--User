// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:chw_tb/config/theme.dart';
import 'package:chw_tb/controllers/providers/patient_provider.dart';
import 'package:chw_tb/models/core_models.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all_patients';
  String _selectedSort = 'date';

  final List<String> _filterOptions = [
    'all_patients',
    'on_treatment',
    'newly_diagnosed',
    'treatment_completed',
    'lost_to_followup',
  ];

  final List<String> _sortOptions = ['date', 'name', 'status'];

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

    // Initialize patient data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final patientProvider = context.read<PatientProvider>();
      patientProvider.initialize();
      // Apply initial filters
      _applyFilters();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Helper method to apply filters consistently
  void _applyFilters() {
    final patientProvider = context.read<PatientProvider>();
    patientProvider.setFilters(
      searchQuery: _searchController.text.trim(),
      statusFilter: _selectedFilter,
      sortBy: _selectedSort,
    );
  }

  String _getFilterDisplayName(String filter) {
    switch (filter) {
      case 'all_patients':
        return 'All Patients';
      case 'on_treatment':
        return 'On Treatment';
      case 'newly_diagnosed':
        return 'Newly Diagnosed';
      case 'treatment_completed':
        return 'Treatment Completed';
      case 'lost_to_followup':
        return 'Lost to Follow-up';
      default:
        return 'All Patients';
    }
  }

  String _getSortDisplayName(String sort) {
    switch (sort) {
      case 'date':
        return 'Registration Date';
      case 'name':
        return 'Name';
      case 'status':
        return 'Status';
      default:
        return 'Registration Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MadadgarTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'My Patients',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: MadadgarTheme.primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/search-patients'),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: _showFilterBottomSheet,
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Search and filter section
            Container(
              color: MadadgarTheme.primaryColor,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search patients by name or ID...',
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey.shade500,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  // Apply filters when search is cleared
                                  _applyFilters();
                                },
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.grey,
                                ),
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        // Add debouncing to avoid too frequent updates
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (_searchController.text == value) {
                            _applyFilters();
                          }
                        });
                      },
                    ),
                  ),

                  // Filter chips
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildActiveFilterChip(),
                                const SizedBox(width: 8),
                                _buildActiveSortChip(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Patient list content
            Expanded(child: _buildPatientList()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/register-patient'),
        backgroundColor: MadadgarTheme.secondaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: Text(
          'Add Patient',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildActiveFilterChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.filter_alt,
            size: 16,
            color: Colors.white.withOpacity(0.9),
          ),
          const SizedBox(width: 4),
          Text(
            _getFilterDisplayName(_selectedFilter),
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSortChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sort, size: 16, color: Colors.white.withOpacity(0.9)),
          const SizedBox(width: 4),
          Text(
            _getSortDisplayName(_selectedSort),
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientList() {
    return Consumer<PatientProvider>(
      builder: (context, patientProvider, child) {
        if (patientProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (patientProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'Error Loading Patients',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  patientProvider.error!,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    patientProvider.loadPatients().then((_) {
                      // Reapply filters after reload
                      _applyFilters();
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    'Retry',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MadadgarTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final filteredPatients = patientProvider.filteredPatients;
        final totalPatients = patientProvider.patients.length;

        if (filteredPatients.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Patient count header - show total vs filtered
                Row(
                  children: [
                    Text(
                      'Patients',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: MadadgarTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '0 of $totalPatients patients',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MadadgarTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Empty state
                // Replace the entire empty state Expanded widget with this:
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64, // Reduced from 80
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12), // Reduced from 16
                          Text(
                            _searchController.text.isNotEmpty ||
                                    _selectedFilter != 'all_patients'
                                ? 'No Patients Match Filters'
                                : 'No Patients Found',
                            style: GoogleFonts.poppins(
                              fontSize: 16, // Reduced from 18
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 6), // Reduced from 8
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              _searchController.text.isNotEmpty ||
                                      _selectedFilter != 'all_patients'
                                  ? 'Try adjusting your search or filters'
                                  : 'Start by registering your first patient',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 20), // Reduced from 24
                          if (_searchController.text.isNotEmpty ||
                              _selectedFilter != 'all_patients')
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 10,
                              ), // Reduced from 12
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _selectedFilter = 'all_patients';
                                    _selectedSort = 'date';
                                  });
                                  _applyFilters();
                                },
                                icon: const Icon(Icons.clear_all),
                                label: Text(
                                  'Clear Filters',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20, // Reduced from 24
                                    vertical: 10, // Reduced from 12
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/register-patient',
                            ),
                            icon: const Icon(Icons.person_add),
                            label: Text(
                              'Register Patient',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MadadgarTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20, // Reduced from 24
                                vertical: 10, // Reduced from 12
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Show patient list
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Patient count header - show filtered vs total
              Row(
                children: [
                  Text(
                    'Patients',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: MadadgarTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      filteredPatients.length == totalPatients
                          ? '${filteredPatients.length} patients'
                          : '${filteredPatients.length} of $totalPatients patients',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MadadgarTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Patient list
              Expanded(
                child: ListView.builder(
                  itemCount: filteredPatients.length,
                  itemBuilder: (context, index) {
                    final patient = filteredPatients[index];
                    return _buildPatientCard(patient);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPatientCard(Patient patient) {
    final statusColor = _getStatusColor(patient.tbStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Select patient and navigate to details
          context.read<PatientProvider>().selectPatientDirect(patient);
          Navigator.pushNamed(
            context,
            '/patient-details',
            arguments: patient.patientId,
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Patient avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: MadadgarTheme.primaryColor.withOpacity(
                      0.1,
                    ),
                    child: Text(
                      patient.name.substring(0, 1).toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: MadadgarTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Patient name and ID
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.name,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'ID: ${patient.patientId}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusDisplayName(patient.tbStatus),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Patient details row
              Row(
                children: [
                  // Age and gender
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          patient.gender == 'male' ? Icons.male : Icons.female,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${patient.age}y, ${patient.gender}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Phone
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.phone,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          patient.phone,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Registration date
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Registered ${_formatDate(patient.createdAt)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Address
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      patient.address,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'newly_diagnosed':
        return Colors.blue.shade600;
      case 'on_treatment':
        return Colors.green.shade600;
      case 'treatment_completed':
        return Colors.purple.shade600;
      case 'lost_to_followup':
        return Colors.red.shade600;
      case 'treatment_failed':
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'newly_diagnosed':
        return 'New';
      case 'on_treatment':
        return 'Treatment';
      case 'treatment_completed':
        return 'Completed';
      case 'lost_to_followup':
        return 'Lost';
      case 'treatment_failed':
        return 'Failed';
      default:
        return 'Unknown';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'today';
    } else if (difference == 1) {
      return 'yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else if (difference < 30) {
      final weeks = (difference / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else if (difference < 365) {
      final months = (difference / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    } else {
      final years = (difference / 365).floor();
      return years == 1 ? '1 year ago' : '$years years ago';
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Text(
                      'Filter & Sort',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          _selectedFilter = 'all_patients';
                          _selectedSort = 'date';
                        });
                        setState(() {
                          _selectedFilter = 'all_patients';
                          _selectedSort = 'date';
                        });
                        _applyFilters();
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Reset',
                        style: GoogleFonts.poppins(
                          color: MadadgarTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Filter section
                      Text(
                        'Filter by Status',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._filterOptions.map(
                        (filter) =>
                            _buildModalFilterOption(filter, setModalState),
                      ),

                      const SizedBox(height: 24),

                      // Sort section
                      Text(
                        'Sort by',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._sortOptions.map(
                        (sort) => _buildModalSortOption(sort, setModalState),
                      ),
                    ],
                  ),
                ),
              ),

              // Apply button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Update main widget state and apply filters
                      setState(() {});
                      _applyFilters();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MadadgarTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Apply Filters',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalFilterOption(String filter, StateSetter setModalState) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setModalState(() {
          _selectedFilter = filter;
        });
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? MadadgarTheme.primaryColor.withOpacity(0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? MadadgarTheme.primaryColor
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? MadadgarTheme.primaryColor : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              _getFilterDisplayName(filter),
              style: GoogleFonts.poppins(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? MadadgarTheme.primaryColor : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalSortOption(String sort, StateSetter setModalState) {
    final isSelected = _selectedSort == sort;
    return GestureDetector(
      onTap: () {
        setModalState(() {
          _selectedSort = sort;
        });
        setState(() {
          _selectedSort = sort;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? MadadgarTheme.primaryColor.withOpacity(0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? MadadgarTheme.primaryColor
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? MadadgarTheme.primaryColor : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              _getSortDisplayName(sort),
              style: GoogleFonts.poppins(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? MadadgarTheme.primaryColor : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
