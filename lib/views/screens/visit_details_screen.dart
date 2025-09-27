// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:chw_tb/config/theme.dart';
import 'package:chw_tb/controllers/providers/patient_provider.dart';
import 'package:chw_tb/models/core_models.dart';

class VisitDetailsScreen extends StatefulWidget {
  final String? visitId;

  const VisitDetailsScreen({super.key, this.visitId});

  @override
  State<VisitDetailsScreen> createState() => _VisitDetailsScreenState();
}

class _VisitDetailsScreenState extends State<VisitDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  Visit? _visit;
  Patient? _patient;
  String? _error;

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

    // Load visit data immediately
    _loadVisitData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _loadVisitData() async {
    if (widget.visitId == null) {
      setState(() {
        _error = 'Visit ID not provided';
      });
      return;
    }

    try {
      final visitProvider = Provider.of<VisitProvider>(context, listen: false);
      final patientProvider = Provider.of<PatientProvider>(
        context,
        listen: false,
      );

      // Load visit details (this will handle its own loading state)
      await visitProvider.selectVisit(widget.visitId!);
      _visit = visitProvider.selectedVisit;

      if (_visit != null) {
        // Load patient details
        _patient = patientProvider.patients
            .where((p) => p.patientId == _visit!.patientId)
            .firstOrNull;
      }

      setState(() {});

      // Start fade animation after data is loaded
      _fadeController.forward();
    } catch (e) {
      setState(() {
        _error = 'Failed to load visit details: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VisitProvider>(
      builder: (context, visitProvider, child) {
        // Handle loading state from provider
        if (visitProvider.isLoading) {
          return Scaffold(
            backgroundColor: MadadgarTheme.backgroundColor,
            appBar: AppBar(
              title: Text(
                'Visit Details',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              backgroundColor: MadadgarTheme.primaryColor,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        // Handle error state
        if (visitProvider.error != null || _error != null) {
          return Scaffold(
            backgroundColor: MadadgarTheme.backgroundColor,
            appBar: AppBar(
              title: Text(
                'Visit Details',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              backgroundColor: MadadgarTheme.primaryColor,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error Loading Visit',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    visitProvider.error ?? _error ?? 'Unknown error',
                    style: GoogleFonts.poppins(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      _loadVisitData();
                    },
                    child: Text('Retry', style: GoogleFonts.poppins()),
                  ),
                ],
              ),
            ),
          );
        }

        // Handle missing visit data
        if (_visit == null) {
          return Scaffold(
            backgroundColor: MadadgarTheme.backgroundColor,
            appBar: AppBar(
              title: Text(
                'Visit Details',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              backgroundColor: MadadgarTheme.primaryColor,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Visit Not Found',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The requested visit could not be found.',
                    style: GoogleFonts.poppins(color: Colors.grey.shade600),
                  ),
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
                  expandedHeight: 280,
                  floating: false,
                  pinned: true,
                  backgroundColor: MadadgarTheme.primaryColor,
                  iconTheme: const IconThemeData(color: Colors.white),
                  actions: [
                    IconButton(
                      onPressed: () => _editVisit(),
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit Visit',
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: _handleMenuAction,
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'duplicate',
                          child: Row(
                            children: [
                              const Icon(Icons.copy),
                              const SizedBox(width: 8),
                              Text(
                                'Duplicate Visit',
                                style: GoogleFonts.poppins(),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'export',
                          child: Row(
                            children: [
                              const Icon(Icons.download),
                              const SizedBox(width: 8),
                              Text(
                                'Export Report',
                                style: GoogleFonts.poppins(),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete, color: Colors.red),
                              const SizedBox(width: 8),
                              Text(
                                'Delete Visit',
                                style: GoogleFonts.poppins(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: _buildHeaderContent(),
                  ),
                  bottom: TabBar(
                    controller: _tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    indicatorColor: Colors.white,
                    labelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    tabs: const [
                      Tab(text: 'Overview'),
                      Tab(text: 'Vitals'),
                      Tab(text: 'Notes'),
                      Tab(text: 'Media'),
                    ],
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildVitalsTab(),
                  _buildNotesTab(),
                  _buildMediaTab(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderContent() {
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
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Visit type badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _formatVisitType(_visit!.visitType),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Patient name
              Text(
                _patient?.name ?? 'Unknown Patient',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 4),

              // Visit date and time
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: Colors.white.withOpacity(0.9),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatVisitDateTime(_visit!.date),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Patient found status
              Row(
                children: [
                  Icon(
                    _visit!.found ? Icons.check_circle : Icons.cancel,
                    color: _visit!.found ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _visit!.found ? 'Patient Found' : 'Patient Not Found',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
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

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Visit summary card
          _buildVisitSummaryCard(),

          const SizedBox(height: 16),

          // Patient information card
          _buildPatientInfoCard(),

          const SizedBox(height: 16),

          // Visit notes card
          _buildVisitNotesCard(),

          if (_visit!.photos != null && _visit!.photos!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildPhotosPreviewCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildVitalsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Vital signs grid
          _buildVitalSignsGrid(),

          const SizedBox(height: 16),

          // Vital signs chart
          _buildVitalSignsChart(),

          const SizedBox(height: 16),

          // Previous readings comparison
          _buildPreviousReadingsCard(),
        ],
      ),
    );
  }

  Widget _buildNotesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // CHW notes
          _buildNotesCard(
            'CHW Notes',
            _visit!.notes.isNotEmpty
                ? _visit!.notes
                : 'No notes recorded for this visit',
          ),

          const SizedBox(height: 16),

          // Patient feedback
          _buildNotesCard('Patient Feedback', 'No patient feedback recorded'),

          const SizedBox(height: 16),

          // Observations
          _buildNotesCard(
            'Clinical Observations',
            'No clinical observations recorded',
          ),

          const SizedBox(height: 16),

          // Action items
          _buildActionItemsCard(),
        ],
      ),
    );
  }

  Widget _buildMediaTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Photos section
          _buildPhotosSection(),

          const SizedBox(height: 16),

          // Documents section
          _buildDocumentsSection(),

          const SizedBox(height: 16),

          // Audio recordings section
          _buildAudioRecordingsSection(),
        ],
      ),
    );
  }

  Widget _buildVisitSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: MadadgarTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Visit Summary',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildSummaryRow('Visit Type', _formatVisitType(_visit!.visitType)),
            _buildSummaryRow(
              'Patient Name',
              _patient?.name ?? 'Unknown Patient',
            ),
            _buildSummaryRow('Visit Date', _formatDate(_visit!.date)),
            _buildSummaryRow('Patient Found', _visit!.found ? 'Yes' : 'No'),
            _buildSummaryRow(
              'GPS Location',
              _visit!.gpsLocation.isNotEmpty ? 'Recorded' : 'Not available',
            ),
            if (_visit!.notes.isNotEmpty)
              _buildSummaryRow('Notes', _visit!.notes),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: MadadgarTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Patient Information',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_patient != null) ...[
              _buildSummaryRow('Patient ID', _patient!.patientId),
              _buildSummaryRow('Age', '${_patient!.age} years'),
              _buildSummaryRow('Gender', _patient!.gender),
              _buildSummaryRow('Phone', _patient!.phone),
              _buildSummaryRow('Address', _patient!.address),
              _buildSummaryRow(
                'TB Status',
                _patient!.tbStatus.replaceAll('_', ' ').toUpperCase(),
              ),
              _buildSummaryRow('Assigned CHW', _patient!.assignedCHW),
              _buildSummaryRow('Assigned Facility', _patient!.assignedFacility),
              if (_patient!.diagnosisDate != null)
                _buildSummaryRow(
                  'Diagnosis Date',
                  _formatDate(_patient!.diagnosisDate!),
                ),
            ] else
              Text(
                'Patient information not available',
                style: GoogleFonts.poppins(color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisitNotesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note_alt, color: MadadgarTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Visit Notes',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_visit!.notes.isNotEmpty)
              Text(
                _visit!.notes,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
              )
            else
              Text(
                'No notes recorded for this visit',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosPreviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_camera, color: MadadgarTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Photos (${_visit!.photos?.length ?? 0})',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_visit!.photos != null && _visit!.photos!.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _visit!.photos!.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade200,
                      ),
                      child: const Icon(
                        Icons.photo,
                        color: Colors.grey,
                        size: 40,
                      ),
                    );
                  },
                ),
              )
            else
              Text(
                'No photos captured during this visit',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helper methods for building UI components
  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalSignsGrid() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vital Signs',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No vital signs recorded for this visit',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalSignsChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vital Signs Chart',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'Chart visualization coming soon',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviousReadingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Previous Readings',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No previous readings available',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(String title, String content) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItemsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Action Items',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No action items recorded',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Photos',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_visit!.photos != null && _visit!.photos!.isNotEmpty)
              Text(
                '${_visit!.photos!.length} photo(s) available',
                style: GoogleFonts.poppins(),
              )
            else
              Text(
                'No photos captured',
                style: GoogleFonts.poppins(color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Documents',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No documents attached',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioRecordingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audio Recordings',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No audio recordings available',
              style: GoogleFonts.poppins(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // Action methods
  void _editVisit() {
    Navigator.pushNamed(context, '/edit-visit', arguments: widget.visitId);
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'duplicate':
        _duplicateVisit();
        break;
      case 'export':
        _exportReport();
        break;
      case 'delete':
        _deleteVisit();
        break;
    }
  }

  void _duplicateVisit() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Duplicate visit feature coming soon!',
          style: GoogleFonts.poppins(),
        ),
      ),
    );
  }

  void _exportReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Export report feature coming soon!',
          style: GoogleFonts.poppins(),
        ),
      ),
    );
  }

  void _deleteVisit() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Visit', style: GoogleFonts.poppins()),
        content: Text(
          'Are you sure you want to delete this visit?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Delete visit feature coming soon!',
                    style: GoogleFonts.poppins(),
                  ),
                ),
              );
            },
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to format visit types for display
  String _formatVisitType(String visitType) {
    switch (visitType.toLowerCase()) {
      case 'home_visit':
        return 'Home Visit';
      case 'follow_up':
        return 'Follow-up Visit';
      case 'tracing':
        return 'Contact Tracing';
      case 'medicine_delivery':
        return 'Medicine Delivery';
      case 'counseling':
        return 'Counseling Session';
      default:
        return visitType.replaceAll('_', ' ').toUpperCase();
    }
  }

  // Helper method to format visit date and time
  String _formatVisitDateTime(DateTime dateTime) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final month = months[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;
    final hour = dateTime.hour;
    final minute = dateTime.minute;

    String period = hour >= 12 ? 'PM' : 'AM';
    int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$day $month $year, ${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  // Helper method to format just the date
  String _formatDate(DateTime dateTime) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final month = months[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;

    return '$day $month $year';
  }
}
