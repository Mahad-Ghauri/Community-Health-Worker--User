// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chw_tb/config/theme.dart';
import 'package:chw_tb/controllers/providers/patient_provider.dart';
import 'package:chw_tb/controllers/providers/secondary_providers.dart';
import 'package:chw_tb/controllers/providers/app_providers.dart';
import 'package:chw_tb/models/core_models.dart';
import 'package:chw_tb/controllers/services/error_handler.dart';

class PatientDetailsScreen extends StatefulWidget {
  final String? patientId;

  const PatientDetailsScreen({super.key, this.patientId});

  @override
  State<PatientDetailsScreen> createState() => _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends State<PatientDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;
  String? patientId;
  Patient? patient;
  String? facilityName;
  List<Followup> _tempFollowups =
      []; // Temporary storage for direct-loaded followups

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
    _tabController = TabController(length: 5, vsync: this);
    _fadeController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (patientId == null) {
      // First try to get patient ID from constructor parameter
      if (widget.patientId != null) {
        patientId = widget.patientId;
      } else {
        // Fallback to route arguments
        final args = ModalRoute.of(context)?.settings.arguments;

        if (args != null) {
          if (args is String) {
            patientId = args;
          } else if (args is Map<String, dynamic>) {
            patientId = args['patientId'];
          }
        }
      }

      if (patientId != null) {
        _loadPatientData();
      }
    }
  }

  Future<void> _loadPatientData() async {
    if (patientId != null) {
      final patientProvider = Provider.of<PatientProvider>(
        context,
        listen: false,
      );
      patient = patientProvider.patients
          .where((p) => p.patientId == patientId)
          .firstOrNull;

      if (patient?.treatmentFacility != null &&
          patient!.treatmentFacility.isNotEmpty) {
        await _loadFacilityName(patient!.treatmentFacility);
      }

      // Load household data for family members
      final householdProvider = Provider.of<HouseholdProvider>(
        context,
        listen: false,
      );
      await householdProvider.loadPatientHousehold(patientId!);

      // Load follow-ups for this patient
      final readOnlyProvider = Provider.of<ReadOnlyDataProvider>(
        context,
        listen: false,
      );

      try {
        // First load assignments to get patient IDs for CHW
        await readOnlyProvider.loadAssignments();

        // Then load follow-ups
        await readOnlyProvider.loadFollowups();

        // Also try direct loading for this specific patient (for debugging)
        await _loadFollowupsDirectly(patientId!);
      } catch (e) {
        // Handle error silently or log appropriately
      }
    }
  }

  Future<void> _loadFacilityName(String facilityId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          facilityName = doc.data()?['name'] ?? 'Unknown Facility';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          facilityName = 'Unknown Facility';
        });
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PatientProvider>(
      builder: (context, patientProvider, child) {
        final currentPatient = patientProvider.selectedPatient;

        // Check if patient changed and load facility name
        if (currentPatient != null && currentPatient != patient) {
          patient = currentPatient;
          facilityName = null; // Reset facility name
          if (patient!.treatmentFacility.isNotEmpty) {
            _loadFacilityName(patient!.treatmentFacility);
          }
        }

        return Scaffold(
          backgroundColor: MadadgarTheme.backgroundColor,
          body: patientProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      SliverAppBar(
                        expandedHeight: 300,
                        floating: false,
                        pinned: true,
                        backgroundColor: MadadgarTheme.primaryColor,
                        iconTheme: const IconThemeData(color: Colors.white),
                        actions: [
                          IconButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/edit-patient',
                                arguments: {'patientId': patientId},
                              );
                            },
                            icon: const Icon(Icons.edit),
                          ),
                          PopupMenuButton<String>(
                            onSelected: _handleMenuAction,
                            icon: const Icon(Icons.more_vert),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'new_visit',
                                child: Row(
                                  children: [
                                    Icon(Icons.add_location),
                                    SizedBox(width: 8),
                                    Text('New Visit'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'add_family',
                                child: Row(
                                  children: [
                                    Icon(Icons.group_add),
                                    SizedBox(width: 8),
                                    Text('Add Family Member'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'call_patient',
                                child: Row(
                                  children: [
                                    Icon(Icons.phone),
                                    SizedBox(width: 8),
                                    Text('Call Patient'),
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
                          isScrollable: true,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white.withOpacity(0.7),
                          indicatorColor: Colors.white,
                          labelStyle: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          tabs: const [
                            Tab(text: 'Overview'),
                            Tab(text: 'Visits'),
                            Tab(text: 'Treatment'),
                            Tab(text: 'Family'),
                            Tab(text: 'Appointments'),
                          ],
                        ),
                      ),
                    ],
                    body: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildVisitsTab(),
                        _buildTreatmentTab(),
                        _buildFamilyTab(),
                        _buildAppointmentsTab(),
                      ],
                    ),
                  ),
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.pushNamed(
              context,
              '/new-visit',
              arguments: {'patientId': patientId},
            ),
            backgroundColor: MadadgarTheme.secondaryColor,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_location),
            label: Text(
              'New Visit',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60), // Space for app bar

              Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient?.name ?? 'Loading...',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              patient?.tbStatus ?? '',
                            ).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusLabel(patient?.tbStatus ?? ''),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${patient?.patientId ?? 'N/A'}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Quick stats
              Row(
                children: [
                  _buildQuickStat('Age', '${patient?.age ?? 0}'),
                  _buildQuickStat('Gender', patient?.gender ?? 'N/A'),
                  _buildQuickStat('Phone', patient?.phone ?? 'N/A'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Personal Information Card
          _buildInfoCard(
            title: 'Personal Information',
            icon: Icons.person_outline,
            children: [
              _buildInfoRow('Full Name', patient?.name ?? 'N/A'),
              _buildInfoRow('Age', '${patient?.age ?? 0} years'),
              _buildInfoRow('Gender', patient?.gender ?? 'N/A'),
              _buildInfoRow('Phone', patient?.phone ?? 'N/A'),
              _buildInfoRow('Address', patient?.address ?? 'N/A'),
            ],
          ),

          const SizedBox(height: 16),

          // Medical Information Card
          _buildInfoCard(
            title: 'Medical Information',
            icon: Icons.medical_information_outlined,
            children: [
              _buildInfoRow(
                'TB Status',
                _getStatusLabel(patient?.tbStatus ?? ''),
              ),
              _buildInfoRow(
                'Diagnosis Date',
                patient?.diagnosisDate != null
                    ? _formatDate(patient!.diagnosisDate!)
                    : 'N/A',
              ),
              _buildInfoRow(
                'Treatment Facility',
                facilityName ?? patient?.treatmentFacility ?? 'N/A',
              ),
              _buildInfoRow(
                'Registration Date',
                patient?.createdAt != null
                    ? _formatDate(patient!.createdAt)
                    : 'N/A',
              ),
              _buildInfoRow(
                'Consent Given',
                patient?.consent == true ? 'Yes' : 'No',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Adherence Score Card
          _buildAdherenceCard(),

          const SizedBox(height: 16),

          // Quick Actions
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildVisitsTab() {
    return Consumer<VisitProvider>(
      builder: (context, visitProvider, child) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'Visit History',
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
                      'Total: ${visitProvider.visits.where((v) => v.patientId == patientId).length}',
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

              Expanded(child: _buildVisitsList(visitProvider)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVisitsList(VisitProvider visitProvider) {
    if (visitProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (visitProvider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Error Loading Visits',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getUserFriendlyErrorMessage(visitProvider.error!),
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.red.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => visitProvider.loadVisits(),
              child: Text('Retry', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      );
    }

    final patientVisits = visitProvider.visits
        .where((visit) => visit.patientId == patientId)
        .toList();

    if (patientVisits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Visits Recorded',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start visiting this patient to see visit history here',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: patientVisits.length,
      itemBuilder: (context, index) {
        final visit = patientVisits[index];
        return _buildVisitCard(visit);
      },
    );
  }

  Widget _buildVisitCard(Visit visit) {
    final statusColor = _getVisitStatusColor(visit.found);
    final statusIcon = _getVisitStatusIcon(visit.found);
    final statusText = visit.found ? 'Patient Found' : 'Patient Not Found';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: () => Navigator.pushNamed(
            context,
            '/visit-details',
            arguments: {'visitId': visit.visitId},
          ),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with status and date
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatVisitDate(visit.date),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Visit type and time
                Row(
                  children: [
                    Icon(
                      Icons.medical_services,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Visit Type: ${visit.visitType}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Time
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Time: ${_formatVisitTime(visit.date)}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),

                // Notes preview (if any)
                if (visit.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.note, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          visit.notes.length > 50
                              ? '${visit.notes.substring(0, 50)}...'
                              : visit.notes,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 8),

                // Tap to view hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Tap to view details',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: MadadgarTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: MadadgarTheme.primaryColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getVisitStatusColor(bool found) {
    return found ? Colors.green : Colors.red;
  }

  IconData _getVisitStatusIcon(bool found) {
    return found ? Icons.check_circle : Icons.cancel;
  }

  String _formatVisitDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference == -1) {
      return 'Tomorrow';
    } else if (difference > 1 && difference <= 7) {
      return 'In $difference days';
    } else if (difference < -1 && difference >= -7) {
      return '${difference.abs()} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatVisitTime(DateTime date) {
    final hour = date.hour == 0
        ? 12
        : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget _buildTreatmentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header with title
          Row(
            children: [
              Text(
                'Treatment Adherence',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Active',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quick actions
          _buildTreatmentActionsCard(),
        ],
      ),
    );
  }

  Widget _buildFamilyTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Family Members',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/add-household-member',
                  arguments: {'patientId': patientId},
                ),
                icon: const Icon(Icons.group_add, size: 16),
                label: Text(
                  'Add Member',
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MadadgarTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(child: _buildFamilyMembersList()),
        ],
      ),
    );
  }

  Widget _buildFamilyMembersList() {
    return Consumer<HouseholdProvider>(
      builder: (context, householdProvider, child) {
        if (householdProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (householdProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'Error Loading Family Data',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  householdProvider.error!,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.red.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final household = householdProvider.selectedHousehold;
        final familyMembers = household?.members ?? [];

        // Show debug info if no members but household exists
        if (familyMembers.isEmpty && household != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.family_restroom,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Household Found but No Members',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Household ID: ${household.householdId}\nPatient ID: ${household.patientId}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (familyMembers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.family_restroom,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Family Members Added',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add family members for contact tracing and screening',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: familyMembers.length,
          itemBuilder: (context, index) {
            final member = familyMembers[index];
            return _buildFamilyMemberCard(
              member,
              household?.householdId,
              household?.patientId,
            );
          },
        );
      },
    );
  }

  Widget _buildFamilyMemberCard(
    HouseholdMember member,
    String? householdId,
    String? patientId,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: member.gender == 'Male'
                ? Colors.blue.shade100
                : Colors.pink.shade100,
            child: Icon(
              member.gender == 'Male' ? Icons.man : Icons.woman,
              color: member.gender == 'Male' ? Colors.blue : Colors.pink,
            ),
          ),
          title: Text(
            member.name,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${member.age} years • ${member.relationship}',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: member.screened
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  member.screened ? 'Screened' : 'Pending Screening',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: member.screened
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          trailing: IconButton(
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/household-member-details',
                arguments: {
                  'member': member,
                  'householdId': householdId,
                  'patientId': patientId,
                },
              );
            },
            icon: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    return Consumer<ReadOnlyDataProvider>(
      builder: (context, readOnlyProvider, child) {
        // Filter follow-ups for this patient
        final patientFollowups = readOnlyProvider.followups
            .where((followup) => followup.patientId == patientId)
            .toList();

        // If no followups from provider, use temp followups
        final finalFollowups = patientFollowups.isEmpty
            ? _tempFollowups
            : patientFollowups;

        // Sort by scheduled date (newest first)
        finalFollowups.sort(
          (a, b) => b.scheduledDate.compareTo(a.scheduledDate),
        );

        if (readOnlyProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (readOnlyProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'Error Loading Follow-ups',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  readOnlyProvider.error!,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.red.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => readOnlyProvider.loadFollowups(),
                  child: Text('Retry', style: GoogleFonts.poppins()),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  Text(
                    'Follow-up Appointments',
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
                      'Total: ${finalFollowups.length}',
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

              // Follow-ups list or empty state
              Expanded(
                child: finalFollowups.isEmpty
                    ? _buildEmptyFollowupsState()
                    : _buildFollowupsList(finalFollowups),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyFollowupsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Follow-ups Scheduled',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Follow-up appointments will appear here when scheduled',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFollowupsList(List<Followup> followups) {
    return ListView.builder(
      itemCount: followups.length,
      itemBuilder: (context, index) {
        final followup = followups[index];
        return _buildFollowupCard(followup);
      },
    );
  }

  Widget _buildFollowupCard(Followup followup) {
    final statusColor = _getFollowupStatusColor(followup.status);
    final statusIcon = _getFollowupStatusIcon(followup.status);
    final isOverdue =
        followup.status == 'scheduled' &&
        followup.scheduledDate.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: () => _showFollowupDialog(followup),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with status and date
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            _getFollowupStatusLabel(followup.status),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (isOverdue)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'OVERDUE',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Scheduled date
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Scheduled: ${_formatFollowupDate(followup.scheduledDate)}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Facility
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        followup.facility.isNotEmpty
                            ? followup.facility
                            : 'No facility specified',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),

                // Completed date (if applicable)
                if (followup.completedDate != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Completed: ${_formatFollowupDate(followup.completedDate!)}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],

                // Notes preview (if any)
                if (followup.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.note, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          followup.notes.length > 50
                              ? '${followup.notes.substring(0, 50)}...'
                              : followup.notes,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 8),

                // Tap to view hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Tap to view details',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: MadadgarTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: MadadgarTheme.primaryColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFollowupDialog(Followup followup) {
    final statusColor = _getFollowupStatusColor(followup.status);
    final statusIcon = _getFollowupStatusIcon(followup.status);
    final isOverdue =
        followup.status == 'scheduled' &&
        followup.scheduledDate.isBefore(DateTime.now());

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.calendar_month,
                    color: MadadgarTheme.primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Follow-up Details',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 18, color: statusColor),
                    const SizedBox(width: 8),
                    Text(
                      _getFollowupStatusLabel(followup.status),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                    if (isOverdue) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'OVERDUE',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Details
              _buildDetailRow('Follow-up ID', followup.followupId),
              _buildDetailRow('Patient ID', followup.patientId),
              _buildDetailRow(
                'Scheduled Date',
                _formatFullDate(followup.scheduledDate),
              ),
              _buildDetailRow(
                'Facility',
                followup.facility.isNotEmpty
                    ? followup.facility
                    : 'Not specified',
              ),

              if (followup.completedDate != null)
                _buildDetailRow(
                  'Completed Date',
                  _formatFullDate(followup.completedDate!),
                ),

              if (followup.notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Notes',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    followup.notes,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MadadgarTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Close',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
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

  Color _getFollowupStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'missed':
        return Colors.red;
      case 'cancelled':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getFollowupStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Icons.schedule;
      case 'completed':
        return Icons.check_circle;
      case 'missed':
        return Icons.warning;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getFollowupStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return 'Scheduled';
      case 'completed':
        return 'Completed';
      case 'missed':
        return 'Missed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  String _formatFollowupDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (difference == 0) {
      return 'Today, ${_formatTime(date)}';
    } else if (difference == 1) {
      return 'Tomorrow, ${_formatTime(date)}';
    } else if (difference == -1) {
      return 'Yesterday, ${_formatTime(date)}';
    } else if (difference > 1 && difference <= 7) {
      return 'In $difference days, ${_formatTime(date)}';
    } else if (difference < -1 && difference >= -7) {
      return '${difference.abs()} days ago, ${_formatTime(date)}';
    } else {
      return '${date.day}/${date.month}/${date.year} at ${_formatTime(date)}';
    }
  }

  String _formatFullDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${_formatTime(date)}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour == 0
        ? 12
        : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _getUserFriendlyErrorMessage(String error) {
    return ErrorHandler.getUserFriendlyMessage(error);
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: MadadgarTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdherenceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: MadadgarTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Treatment Adherence',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'N/A',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      Text(
                        'Adherence Score',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 60, color: Colors.grey.shade300),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '0',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      Text(
                        'Days on Treatment',
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
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.add_location,
                    label: 'New Visit',
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/new-visit',
                      arguments: {'patientId': patientId},
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.phone,
                    label: 'Call Patient',
                    onTap: () => _callPatient(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.edit,
                    label: 'Edit Info',
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/edit-patient',
                      arguments: {'patientId': patientId},
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.medication,
                    label: 'Log Adherence',
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/adherence-tracking',
                      arguments: {'patientId': patientId},
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: MadadgarTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: MadadgarTheme.primaryColor.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: MadadgarTheme.primaryColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: MadadgarTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'new_visit':
        Navigator.pushNamed(
          context,
          '/new-visit',
          arguments: {'patientId': patientId},
        );
        break;
      case 'add_family':
        Navigator.pushNamed(
          context,
          '/add-household-member',
          arguments: {'patientId': patientId},
        );
        break;
      case 'call_patient':
        _callPatient();
        break;
    }
  }

  void _callPatient() {
    if (patient?.phone != null && patient!.phone.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Calling ${patient!.phone}...',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No phone number available',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'on_treatment':
        return 'On Treatment';
      case 'treatment_completed':
        return 'Treatment Completed';
      case 'treatment_failed':
        return 'Treatment Failed';
      case 'lost_to_followup':
        return 'Lost to Follow-up';
      case 'died':
        return 'Died';
      case 'not_evaluated':
        return 'Not Evaluated';
      case 'transferred_out':
        return 'Transferred Out';
      default:
        return 'Unknown Status';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'on_treatment':
        return Colors.blue;
      case 'treatment_completed':
        return Colors.green;
      case 'treatment_failed':
        return Colors.red;
      case 'lost_to_followup':
        return Colors.orange;
      case 'died':
        return Colors.black;
      case 'not_evaluated':
        return Colors.grey;
      case 'transferred_out':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildTreatmentActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewFullAdherence(),
                    icon: const Icon(Icons.analytics, size: 16),
                    label: Text(
                      'Full Tracking',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _exportAdherenceData(),
                    icon: const Icon(Icons.download, size: 16),
                    label: Text(
                      'Export Data',
                      style: GoogleFonts.poppins(fontSize: 12),
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

  void _viewFullAdherence() {
    if (patientId != null) {
      Navigator.pushNamed(
        context,
        '/adherence-tracking',
        arguments: {'patientId': patientId},
      );
    }
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

  /// Load follow-ups directly for a specific patient
  Future<void> _loadFollowupsDirectly(String patientId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('followups')
          .where('patientId', isEqualTo: patientId)
          .get();

      final List<Followup> directFollowups = [];

      for (var doc in snapshot.docs) {
        // Try to parse the data
        try {
          final followup = Followup.fromFirestore(doc.data());
          directFollowups.add(followup);
        } catch (e) {
          // Handle parsing error silently
        }
      }

      // Update the provider with the direct results for this session
      if (directFollowups.isNotEmpty && mounted) {
        await _updateProviderFollowups(directFollowups);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  /// Temporarily update provider with direct follow-ups
  Future<void> _updateProviderFollowups(List<Followup> followups) async {
    // Create a temporary method to load just this patient's follow-ups
    await _loadSinglePatientFollowups(patientId!);
  }

  /// Load follow-ups for a single patient (bypass assignment check)
  Future<void> _loadSinglePatientFollowups(String patientId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('followups')
          .where('patientId', isEqualTo: patientId)
          .orderBy('scheduledDate', descending: true)
          .get();

      final followups = snapshot.docs
          .map((doc) => Followup.fromFirestore(doc.data()))
          .toList();

      // Store them locally for this session
      if (mounted) {
        setState(() {
          _tempFollowups = followups;
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }
}
