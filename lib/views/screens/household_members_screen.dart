// ignore_for_file: deprecated_member_use, avoid_print

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:chw_tb/config/theme.dart';
import 'package:chw_tb/controllers/providers/patient_provider.dart';
import 'package:chw_tb/controllers/providers/secondary_providers.dart';
import 'package:chw_tb/models/core_models.dart';

class HouseholdMembersScreen extends StatefulWidget {
  final String? patientId;
  
  const HouseholdMembersScreen({super.key, this.patientId});

  @override
  State<HouseholdMembersScreen> createState() => _HouseholdMembersScreenState();
}

class _HouseholdMembersScreenState extends State<HouseholdMembersScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  bool _isLoading = true;
  String _selectedFilter = 'all';
  String? _error;
  
  // Patient and household data
  Patient? _patient;
  Household? _household;
  List<HouseholdMember> _householdMembers = [];
  Map<String, dynamic> _householdStats = {};

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _fadeController.forward();
    
    _loadHouseholdData();
  }

  @override
  void didUpdateWidget(HouseholdMembersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('👥 HouseholdScreen: didUpdateWidget called');
    print('👥 HouseholdScreen: Old patient ID: ${oldWidget.patientId}');
    print('👥 HouseholdScreen: New patient ID: ${widget.patientId}');
    // If the patient ID changed, reload the data
    if (oldWidget.patientId != widget.patientId) {
      print('👥 HouseholdScreen: Patient ID changed, reloading data...');
      _loadHouseholdData();
    }
  }

  @override
  void dispose() {
    print('👥 HouseholdScreen: Disposing - clearing household data');
    _fadeController.dispose();
    // Clear the household provider data when leaving the screen
    final householdProvider = Provider.of<HouseholdProvider>(context, listen: false);
    householdProvider.clearHouseholdData();
    super.dispose();
  }

  void _loadHouseholdData() async {
    print('👥 HouseholdScreen: Starting to load household data for patient: ${widget.patientId}');
    
    if (widget.patientId == null) {
      print('👥 HouseholdScreen ERROR: Patient ID is null');
      setState(() {
        _error = 'Patient ID not provided';
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
        // Clear existing data
        _householdMembers.clear();
        _household = null;
        _householdStats.clear();
      });

      print('👥 HouseholdScreen: Getting providers...');
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      final householdProvider = Provider.of<HouseholdProvider>(context, listen: false);
      
      // Find the patient by ID
      _patient = patientProvider.patients
          .where((p) => p.patientId == widget.patientId)
          .firstOrNull;
      
      print('👥 HouseholdScreen: Found patient: ${_patient?.name ?? 'Not found'}');
      
      if (_patient != null) {
        print('👥 HouseholdScreen: Loading household data from provider...');
        // Load real household data from Firestore for this specific patient
        await householdProvider.loadPatientHousehold(widget.patientId!);
        
        // Get the household and its members
        _household = householdProvider.selectedHousehold;
        _householdMembers = _household?.members ?? [];
        
        print('👥 HouseholdScreen: Received household: ${_household?.householdId ?? 'null'}');
        print('👥 HouseholdScreen: Household patient ID: ${_household?.patientId ?? 'null'}');
        print('👥 HouseholdScreen: Number of members: ${_householdMembers.length}');
        print('🏠 Full Household Debug:');
        if (_household != null) {
          print('   - householdId: "${_household!.householdId}"');
          print('   - patientId: "${_household!.patientId}"');
          print('   - address: "${_household!.address}"');
        } else {
          print('   - _household is null!');
        }
        
        for (int i = 0; i < _householdMembers.length; i++) {
          final member = _householdMembers[i];
          print('👥 HouseholdScreen: Member $i: ${member.name} (${member.relationship})');
        }
        
        _calculateHouseholdStats();
      } else {
        print('👥 HouseholdScreen ERROR: Patient not found in provider');
        _error = 'Patient not found';
      }
      
      setState(() => _isLoading = false);
      print('👥 HouseholdScreen: Finished loading household data');
    } catch (e) {
      print('👥 HouseholdScreen ERROR: Exception occurred: $e');
      setState(() {
        _error = 'Failed to load household data: $e';
        _isLoading = false;
      });
    }
  }

  void _calculateHouseholdStats() {
    _householdStats = {
      'totalMembers': _householdMembers.length,
      'screenedMembers': _householdMembers.where((m) => m.screened).length,
      'pendingScreening': _householdMembers.where((m) => !m.screened).length,
      'overdueScreening': 0, // Would need additional logic for overdue calculation
      'highRiskMembers': _householdMembers.length, // All household members are considered high risk
      'symptomatic': 0, // Would need symptom tracking in the model
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MadadgarTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Household Members',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: MadadgarTheme.primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () => _showHouseholdInfo(),
            icon: const Icon(Icons.info_outline),
            tooltip: 'Household Information',
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
                    Text('Export List', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'print',
                child: Row(
                  children: [
                    const Icon(Icons.print),
                    const SizedBox(width: 8),
                    Text('Print Report', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'schedule_all',
                child: Row(
                  children: [
                    const Icon(Icons.schedule),
                    const SizedBox(width: 8),
                    Text('Schedule All Screening', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<HouseholdProvider>(
        builder: (context, householdProvider, child) {
          print('👥 HouseholdScreen Consumer: Provider state changed');
          print('👥 HouseholdScreen Consumer: Provider selected household: ${householdProvider.selectedHousehold?.householdId ?? 'null'}');
          print('👥 HouseholdScreen Consumer: Provider household patient ID: ${householdProvider.selectedHousehold?.patientId ?? 'null'}');
          print('👥 HouseholdScreen Consumer: Current widget patient ID: ${widget.patientId}');
          
          // Only update local state if the data belongs to the current patient
          if (householdProvider.selectedHousehold != null && 
              householdProvider.selectedHousehold!.patientId == widget.patientId) {
            print('👥 HouseholdScreen Consumer: Updating local state with provider data');
            // Update local state when provider changes
            _household = householdProvider.selectedHousehold;
            _householdMembers = _household?.members ?? [];
            print('👥 HouseholdScreen Consumer: Updated local members count: ${_householdMembers.length}');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _calculateHouseholdStats();
                });
              }
            });
          } else if (householdProvider.selectedHousehold != null) {
            print('👥 HouseholdScreen Consumer: WARNING - Provider data is for different patient!');
            print('👥 HouseholdScreen Consumer: Provider patient: ${householdProvider.selectedHousehold!.patientId}');
            print('👥 HouseholdScreen Consumer: Expected patient: ${widget.patientId}');
          }
          
          if (householdProvider.error != null) {
            print('👥 HouseholdScreen Consumer: Provider has error: ${householdProvider.error}');
            _error = householdProvider.error;
          }
          
          return FadeTransition(
            opacity: _fadeAnimation,
            child: _isLoading || householdProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorState()
                    : Column(
                        children: [
                          _buildIndexCaseHeader(),
                          _buildHouseholdStats(),
                          _buildFilterTabs(),
                          Expanded(
                            child: _buildMembersList(),
                          ),
                        ],
                      ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addHouseholdMember(),
        backgroundColor: MadadgarTheme.primaryColor,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: Text(
          'Add Member',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildIndexCaseHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade700, Colors.red.shade500],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.coronavirus,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'INDEX CASE',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'TB POSITIVE',
                            style: GoogleFonts.poppins(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _patient?.name ?? 'Unknown Patient',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Patient ID: ${_patient?.patientId ?? 'Unknown'}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Debug info - show current patient ID and household ID
          if (_household != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.white, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Household ID: ${_household!.householdId} | Patient: ${_household!.patientId}',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 8),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.home, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _patient?.address ?? 'No address available',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHouseholdStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics, color: MadadgarTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Household Screening Status',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.2,
                children: [
                  _buildStatCard(
                    'Total Members',
                    '${_householdStats['totalMembers']}',
                    Icons.group,
                    MadadgarTheme.primaryColor,
                  ),
                  _buildStatCard(
                    'Screened',
                    '${_householdStats['screenedMembers']}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                  _buildStatCard(
                    'Pending',
                    '${_householdStats['pendingScreening']}',
                    Icons.schedule,
                    Colors.orange,
                  ),
                  _buildStatCard(
                    'Overdue',
                    '${_householdStats['overdueScreening']}',
                    Icons.warning,
                    Colors.red,
                  ),
                  _buildStatCard(
                    'High Risk',
                    '${_householdStats['highRiskMembers']}',
                    Icons.priority_high,
                    Colors.deepOrange,
                  ),
                  _buildStatCard(
                    'Symptomatic',
                    '${_householdStats['symptomatic']}',
                    Icons.sick,
                    Colors.red.shade600,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = [
      {'key': 'all', 'label': 'All Members'},
      {'key': 'pending', 'label': 'Pending'},
      {'key': 'overdue', 'label': 'Overdue'},
      {'key': 'completed', 'label': 'Completed'},
      {'key': 'high_risk', 'label': 'High Risk'},
      {'key': 'symptomatic', 'label': 'Symptomatic'},
    ];
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            bool isSelected = _selectedFilter == filter['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: isSelected,
                label: Text(
                  filter['label']!,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isSelected ? Colors.white : MadadgarTheme.primaryColor,
                  ),
                ),
                selectedColor: MadadgarTheme.primaryColor,
                backgroundColor: Colors.white,
                side: BorderSide(color: MadadgarTheme.primaryColor),
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = filter['key']!;
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMembersList() {
    List<HouseholdMember> filteredMembers = _getFilteredMembers();
    
    print('👥 HouseholdScreen: Building members list with ${filteredMembers.length} filtered members');
    print('👥 HouseholdScreen: Total members in _householdMembers: ${_householdMembers.length}');
    print('👥 HouseholdScreen: Selected filter: $_selectedFilter');
    
    if (filteredMembers.isEmpty) {
      print('👥 HouseholdScreen: No filtered members found, showing empty state');
      return _buildEmptyState();
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredMembers.length,
      itemBuilder: (context, index) {
        print('👥 HouseholdScreen: Building member card for index $index: ${filteredMembers[index].name}');
        return _buildMemberCard(filteredMembers[index]);
      },
    );
  }

  List<HouseholdMember> _getFilteredMembers() {
    switch (_selectedFilter) {
      case 'pending':
        return _householdMembers.where((m) => !m.screened).toList();
      case 'overdue':
        // In a real implementation, you would check for overdue based on last screening date
        return _householdMembers.where((m) => !m.screened).toList();
      case 'completed':
        return _householdMembers.where((m) => m.screened).toList();
      case 'high_risk':
        // For now, consider all members high risk (since they're household contacts)
        return _householdMembers;
      case 'symptomatic':
        // Would need symptom tracking in the model
        return [];
      default:
        return _householdMembers;
    }
  }

  Widget _buildMemberCard(HouseholdMember member) {
    Color statusColor = _getStatusColor(member.screeningStatus);
    Color riskColor = Colors.orange; // Default to medium risk since we don't have risk level in model
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Card(
        elevation: 2,
        child: InkWell(
          onTap: () => _viewMemberDetails(member),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: _getGenderColor(member.gender).withOpacity(0.1),
                      child: Icon(
                        member.gender == 'Male' ? Icons.man : Icons.woman,
                        color: _getGenderColor(member.gender),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  member.name,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${member.age} years • ${member.relationship}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            member.screeningStatus.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: riskColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'MEDIUM RISK', // Since we don't have risk level in the model
                            style: GoogleFonts.poppins(
                              fontSize: 8,
                              color: riskColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Contact and screening info
                Row(
                  children: [
                    if (member.phone != null) ...[
                      Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        member.phone!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ] else ...[
                      Icon(Icons.phone_disabled, size: 16, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        'No phone',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (member.lastScreeningDate != null) ...[
                      Icon(Icons.event, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Last screened: ${_formatDate(member.lastScreeningDate!)}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
                
                // Action buttons
                const SizedBox(height: 12),
                
                // Action buttons
                Row(
                  children: [
                    if (!member.screened) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _startScreening(member),
                          icon: Icon(Icons.medical_services, size: 16),
                          label: Text(
                            'Start Screening',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    
                    if (member.phone != null)
                      OutlinedButton.icon(
                        onPressed: () => _callMember(member),
                        icon: Icon(Icons.phone, size: 16),
                        label: Text(
                          'Call',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        ),
                      ),
                    
                    const SizedBox(width: 8),
                    
                    PopupMenuButton<String>(
                      onSelected: (action) => _handleMemberAction(action, member),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit, size: 16),
                              const SizedBox(width: 8),
                              Text('Edit Details', style: GoogleFonts.poppins(fontSize: 12)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'history',
                          child: Row(
                            children: [
                              const Icon(Icons.history, size: 16),
                              const SizedBox(width: 8),
                              Text('Screening History', style: GoogleFonts.poppins(fontSize: 12)),
                            ],
                          ),
                        ),
                        if (member.screened)
                          PopupMenuItem(
                            value: 'reschedule',
                            child: Row(
                              children: [
                                const Icon(Icons.schedule, size: 16),
                                const SizedBox(width: 8),
                                Text('Reschedule', style: GoogleFonts.poppins(fontSize: 12)),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              const Icon(Icons.delete, size: 16, color: Colors.red),
                              const SizedBox(width: 8),
                              Text('Remove', style: GoogleFonts.poppins(fontSize: 12, color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No household members found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            'Add family members to start contact tracing',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _addHouseholdMember(),
            icon: const Icon(Icons.person_add),
            label: Text(
              'Add First Member',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: MadadgarTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Household Data',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.red.shade600,
            ),
          ),
          Text(
            _error ?? 'Unknown error occurred',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _loadHouseholdData(),
            icon: const Icon(Icons.refresh),
            label: Text(
              'Retry',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: MadadgarTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'scheduled':
        return Colors.blue;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getGenderColor(String gender) {
    return gender == 'Male' ? Colors.blue : Colors.pink;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _addHouseholdMember() {
    Navigator.pushNamed(context, '/add-household-member', arguments: {
      'patientId': widget.patientId,
      'householdId': _household?.householdId,
    });
  }

  void _viewMemberDetails(HouseholdMember member) {
    print('🏠 Navigation Debug - _viewMemberDetails called');
    print('   - Member: ${member.name}');
    print('   - _household?.householdId: ${_household?.householdId}');
    print('   - widget.patientId: ${widget.patientId}');
    
    final args = {
      'member': member,
      'householdId': _household?.householdId,
      'patientId': widget.patientId,
    };
    
    print('🏠 Navigation Debug - Arguments being passed:');
    print('   - args: $args');
    print('   - args type: ${args.runtimeType}');
    print('   - householdId in args: ${args['householdId']}');
    print('   - patientId in args: ${args['patientId']}');
    
    Navigator.pushNamed(context, '/household-member-details', arguments: args);
  }

  void _startScreening(HouseholdMember member) {
    Navigator.pushNamed(context, '/contact-screening', arguments: {
      'memberInfo': {
        'name': member.name,
        'age': member.age,
        'gender': member.gender,
        'relationship': member.relationship,
        'phone': member.phone,
        'screened': member.screened,
        'screeningStatus': member.screeningStatus,
        'lastScreeningDate': member.lastScreeningDate,
      },
      'patientId': widget.patientId,
      'householdId': _household?.householdId,
    });
  }


  void _callMember(HouseholdMember member) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Calling ${member.name}...', style: GoogleFonts.poppins())),
    );
  }

  void _handleMemberAction(String action, HouseholdMember member) {
    switch (action) {
      case 'edit':
        _editMember(member);
        break;
      case 'history':
        _viewHistory(member);
        break;
      case 'reschedule':
        _rescheduleScreening(member);
        break;
      case 'remove':
        _removeMember(member);
        break;
    }
  }

  void _editMember(HouseholdMember member) {
    Navigator.pushNamed(context, '/edit-household-member', arguments: member);
  }

  void _viewHistory(HouseholdMember member) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Screening history feature coming soon!', style: GoogleFonts.poppins())),
    );
  }

  void _rescheduleScreening(HouseholdMember member) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reschedule screening feature coming soon!', style: GoogleFonts.poppins())),
    );
  }

  void _removeMember(HouseholdMember member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Member', style: GoogleFonts.poppins()),
        content: Text(
          'Are you sure you want to remove ${member.name} from the household?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _householdMembers.removeWhere((m) => m.name == member.name);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Member removed', style: GoogleFonts.poppins())),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Remove', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showHouseholdInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Household info feature coming soon!', style: GoogleFonts.poppins())),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'export':
        _exportList();
        break;
      case 'print':
        _printReport();
        break;
      case 'schedule_all':
        _scheduleAllScreening();
        break;
    }
  }

  void _exportList() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Export list feature coming soon!', style: GoogleFonts.poppins())),
    );
  }

  void _printReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Print report feature coming soon!', style: GoogleFonts.poppins())),
    );
  }

  void _scheduleAllScreening() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Schedule all screening feature coming soon!', style: GoogleFonts.poppins())),
    );
  }
}