// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chw_tb/config/theme.dart';
import 'package:chw_tb/models/core_models.dart';

class HouseholdMemberDetailsScreen extends StatefulWidget {
  final HouseholdMember member;
  final String? householdId;
  final String? patientId;
  
  const HouseholdMemberDetailsScreen({
    super.key, 
    required this.member,
    this.householdId,
    this.patientId,
  });

  @override
  State<HouseholdMemberDetailsScreen> createState() => _HouseholdMemberDetailsScreenState();
}

class _HouseholdMemberDetailsScreenState extends State<HouseholdMemberDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  bool _isLoading = true;
  String? _error;
  List<ContactTracing> _screeningHistory = [];
  ContactTracing? _latestScreening;
  Map<String, dynamic> _memberStats = {};

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
    _tabController = TabController(length: 3, vsync: this);
    _fadeController.forward();
    
    _loadMemberData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMemberData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load screening history for this member from Firestore
      final QuerySnapshot screeningQuery = await FirebaseFirestore.instance
          .collection('contactTracing')
          .where('contactName', isEqualTo: widget.member.name)
          .orderBy('screeningDate', descending: true)
          .get();

      _screeningHistory = screeningQuery.docs
          .map((doc) => ContactTracing.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();

      // Get latest screening
      _latestScreening = _screeningHistory.isNotEmpty ? _screeningHistory.first : null;

      // Calculate member statistics
      _calculateMemberStats();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to load member data: $e';
        _isLoading = false;
      });
    }
  }

  void _calculateMemberStats() {
    _memberStats = {
      'totalScreenings': _screeningHistory.length,
      'lastScreeningDate': _latestScreening?.screeningDate,
      'riskLevel': _calculateRiskLevel(),
      'symptomsCount': _latestScreening?.symptoms.length ?? 0,
      'testResults': _getTestResults(),
      'referralStatus': _latestScreening?.referralNeeded ?? false,
    };
  }

  String _calculateRiskLevel() {
    if (_latestScreening == null) return 'Unknown';
    
    final symptomsCount = _latestScreening!.symptoms.length;
    final age = widget.member.age;
    
    if (symptomsCount >= 3 || age < 5) return 'High';
    if (symptomsCount >= 1 || age > 65) return 'Medium';
    return 'Low';
  }

  Map<String, int> _getTestResults() {
    Map<String, int> results = {
      'positive': 0,
      'negative': 0,
      'pending': 0,
      'inconclusive': 0,
    };

    for (var screening in _screeningHistory) {
      final result = screening.testResult.toLowerCase();
      if (results.containsKey(result)) {
        results[result] = results[result]! + 1;
      }
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
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
                  onPressed: () => _editMember(),
                  icon: const Icon(Icons.edit),
                ),
                PopupMenuButton<String>(
                  onSelected: _handleMenuAction,
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'new_screening',
                      child: Row(
                        children: [
                          Icon(Icons.medical_services),
                          SizedBox(width: 8),
                          Text('New Screening'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'call_member',
                      child: Row(
                        children: [
                          Icon(Icons.phone),
                          SizedBox(width: 8),
                          Text('Call Member'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'export_history',
                      child: Row(
                        children: [
                          Icon(Icons.download),
                          SizedBox(width: 8),
                          Text('Export History'),
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
                unselectedLabelColor: Colors.white.withOpacity(0.7),
                indicatorColor: Colors.white,
                labelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Screening History'),
                  Tab(text: 'Test Results'),
                ],
              ),
            ),
          ],
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildErrorState()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildScreeningHistoryTab(),
                        _buildTestResultsTab(),
                      ],
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startNewScreening(),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.medical_services),
        label: Text(
          'New Screening',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
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
                      color: _getGenderColor(widget.member.gender).withOpacity(0.3),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      widget.member.gender == 'Male' ? Icons.man : Icons.woman,
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
                          widget.member.name,
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
                            color: _getRiskColor(_calculateRiskLevel()).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_calculateRiskLevel()} Risk',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.member.age} years • ${widget.member.relationship}',
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
              
              const SizedBox(height: 20),
              
              // Quick stats
              Row(
                children: [
                  _buildQuickStat('Screenings', '${_memberStats['totalScreenings'] ?? 0}'),
                  _buildQuickStat('Symptoms', '${_memberStats['symptomsCount'] ?? 0}'),
                  _buildQuickStat('Status', widget.member.screened ? 'Screened' : 'Pending'),
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
          // Member Information Card
          _buildInfoCard(
            title: 'Member Information',
            icon: Icons.person_outline,
            children: [
              _buildInfoRow('Full Name', widget.member.name),
              _buildInfoRow('Age', '${widget.member.age} years'),
              _buildInfoRow('Gender', widget.member.gender),
              _buildInfoRow('Relationship', widget.member.relationship),
              _buildInfoRow('Phone', widget.member.phone ?? 'Not provided'),
              _buildInfoRow('Screening Status', widget.member.screened ? 'Completed' : 'Pending'),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Risk Assessment Card
          _buildRiskAssessmentCard(),
          
          const SizedBox(height: 16),
          
          // Latest Screening Card
          if (_latestScreening != null) _buildLatestScreeningCard(),
          
          const SizedBox(height: 16),
          
          // Contact Information Card
          _buildContactInfoCard(),
        ],
      ),
    );
  }

  Widget _buildScreeningHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('contactTracing')
          .where('contactName', isEqualTo: widget.member.name)
          .orderBy('screeningDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final screenings = snapshot.data?.docs
            .map((doc) => ContactTracing.fromFirestore(doc.data() as Map<String, dynamic>))
            .toList() ?? [];

        if (screenings.isEmpty) {
          return _buildEmptyScreeningHistory();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: screenings.length,
          itemBuilder: (context, index) {
            return _buildScreeningHistoryCard(screenings[index]);
          },
        );
      },
    );
  }

  Widget _buildTestResultsTab() {
    // First get the ContactTracing record to find the contactId
    // Use householdId filter for more precise queries when available
    final query = widget.householdId?.isNotEmpty == true
        ? FirebaseFirestore.instance
            .collection('contactTracing')
            .where('contactName', isEqualTo: widget.member.name)
            .where('householdId', isEqualTo: widget.householdId!)
            .limit(1)
        : FirebaseFirestore.instance
            .collection('contactTracing')
            .where('contactName', isEqualTo: widget.member.name)
            .limit(1);
            
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, contactSnapshot) {

        if (contactSnapshot.hasError) {
          return Center(child: Text('Error loading contact: ${contactSnapshot.error}'));
        }

        if (contactSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!contactSnapshot.hasData || contactSnapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_search, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No contact record found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'This member needs to be screened first.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // Get the contactId from the ContactTracing record
        final contactDoc = contactSnapshot.data!.docs.first;
        final contactId = contactDoc.id;

        // Now query ScreeningResults using the contactId
        // Note: Removed orderBy to avoid index requirement for now
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('screeningResults')
              .where('contactId', isEqualTo: contactId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error loading test results: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final results = snapshot.data?.docs
                .map((doc) => ScreeningResult.fromFirestore(doc.data() as Map<String, dynamic>))
                .toList() ?? [];

            // Sort results by testDate in descending order (newest first)
            results.sort((a, b) => b.testDate.compareTo(a.testDate));

            if (results.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.science_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No test results available',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Test results will appear here once screening is completed.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildTestResultsSummary(results),
                  const SizedBox(height: 16),
                  ...results.map((result) => _buildDetailedTestResultCard(result)).toList(),
                ],
              ),
            );
          },
        );
      },
    );
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
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskAssessmentCard() {
    final riskLevel = _calculateRiskLevel();
    final riskColor = _getRiskColor(riskLevel);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assessment, color: MadadgarTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Risk Assessment',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: riskColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: riskColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(
                    _getRiskIcon(riskLevel),
                    color: riskColor,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$riskLevel Risk',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: riskColor,
                    ),
                  ),
                  Text(
                    _getRiskDescription(riskLevel),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestScreeningCard() {
    if (_latestScreening == null) return const SizedBox();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medical_services, color: MadadgarTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Latest Screening',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(_latestScreening!.screeningDate),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_latestScreening!.symptoms.isNotEmpty) ...[
              Text(
                'Symptoms Reported:',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _latestScreening!.symptoms.map((symptom) {
                  return Chip(
                    label: Text(
                      symptom.replaceAll('_', ' ').toUpperCase(),
                      style: GoogleFonts.poppins(fontSize: 10),
                    ),
                    backgroundColor: Colors.red.shade100,
                    labelStyle: TextStyle(color: Colors.red.shade700),
                  );
                }).toList(),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'No symptoms reported',
                      style: GoogleFonts.poppins(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildStatusChip(
                    'Test Result',
                    _latestScreening!.testResult.toUpperCase(),
                    _getTestResultColor(_latestScreening!.testResult),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatusChip(
                    'Referral',
                    _latestScreening!.referralNeeded ? 'NEEDED' : 'NOT NEEDED',
                    _latestScreening!.referralNeeded ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.contact_phone, color: MadadgarTheme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Contact Information',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (widget.member.phone != null) ...[
              ListTile(
                leading: const Icon(Icons.phone),
                title: Text(
                  widget.member.phone!,
                  style: GoogleFonts.poppins(),
                ),
                subtitle: Text(
                  'Primary contact number',
                  style: GoogleFonts.poppins(fontSize: 12),
                ),
                trailing: IconButton(
                  onPressed: () => _callMember(),
                  icon: const Icon(Icons.call),
                ),
              ),
            ] else ...[
              ListTile(
                leading: Icon(Icons.phone_disabled, color: Colors.grey.shade400),
                title: Text(
                  'No phone number provided',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                ),
                subtitle: Text(
                  'Consider adding contact information',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScreeningHistoryCard(ContactTracing screening) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.medical_services,
                  color: _getTestResultColor(screening.testResult),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Screening ${_formatDate(screening.screeningDate)}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getTestResultColor(screening.testResult).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    screening.testResult.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: _getTestResultColor(screening.testResult),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            if (screening.symptoms.isNotEmpty) ...[
              Text(
                'Symptoms (${screening.symptoms.length}):',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                screening.symptoms.join(', ').replaceAll('_', ' '),
                style: GoogleFonts.poppins(fontSize: 12),
              ),
            ] else ...[
              Text(
                'No symptoms reported',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            
            if (screening.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Notes:',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
              Text(
                screening.notes,
                style: GoogleFonts.poppins(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            
            const SizedBox(height: 8),
            
            Row(
              children: [
                if (screening.referralNeeded)
                  Chip(
                    label: Text(
                      'REFERRAL NEEDED',
                      style: GoogleFonts.poppins(fontSize: 10),
                    ),
                    backgroundColor: Colors.orange.shade100,
                    labelStyle: TextStyle(color: Colors.orange.shade700),
                  ),
                const Spacer(),
                Text(
                  'Screened by CHW',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.black45,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResultsSummary(List<ScreeningResult> results) {
    Map<String, int> testResults = {
      'positive': 0,
      'negative': 0,
      'pending': 0,
      'inconclusive': 0,
    };

    for (var result in results) {
      final testResult = result.testResult.toLowerCase();
      if (testResults.containsKey(testResult)) {
        testResults[testResult] = testResults[testResult]! + 1;
      }
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Test Results Summary',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2,
              children: [
                _buildResultStat('Positive', testResults['positive']!, Colors.red),
                _buildResultStat('Negative', testResults['negative']!, Colors.green),
                _buildResultStat('Pending', testResults['pending']!, Colors.orange),
                _buildResultStat('Inconclusive', testResults['inconclusive']!, Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedTestResultCard(ScreeningResult result) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.science,
                  color: _getTestResultColor(result.testResult),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${result.testTypeName} - ${_formatDate(result.testDate)}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getTestResultColor(result.testResult).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    result.testResult.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: _getTestResultColor(result.testResult),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Test result box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getTestResultColor(result.testResult).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getTestResultColor(result.testResult).withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.testResult.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _getTestResultColor(result.testResult),
                    ),
                  ),
                  if (result.notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      result.notes,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Facility and conducted by info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Facility',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        result.testFacility,
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conducted By',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        result.conductedBy,
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Test details (if available)
            if (result.testDetails.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Test Details',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              ...result.testDetails.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          entry.key.replaceAll('_', ' ').toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value.toString(),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
            
            // Follow-up info
            if (result.requiresFollowUp && result.nextTestDate != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.blue.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Next test due: ${_formatDate(result.nextTestDate!)}',
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
            
            // Contact info
            if (result.facilityContact.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    result.facilityContact,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Recorded by CHW',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultStat(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            count.toString(),
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyScreeningHistory() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medical_services_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Screening History',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            'Start the first screening for this member',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _startNewScreening(),
            icon: const Icon(Icons.medical_services),
            label: Text(
              'Start Screening',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
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
            'Error Loading Data',
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
            onPressed: () => _loadMemberData(),
            icon: const Icon(Icons.refresh),
            label: Text(
              'Retry',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: MadadgarTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Color _getGenderColor(String gender) {
    return gender == 'Male' ? Colors.blue : Colors.pink;
  }

  Color _getRiskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getRiskIcon(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
        return Icons.dangerous;
      case 'medium':
        return Icons.warning;
      case 'low':
        return Icons.check_circle;
      default:
        return Icons.help;
    }
  }

  String _getRiskDescription(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
        return 'Requires immediate attention and regular monitoring';
      case 'medium':
        return 'Schedule regular follow-up screenings';
      case 'low':
        return 'Continue routine screening as recommended';
      default:
        return 'Risk assessment pending';
    }
  }

  Color _getTestResultColor(String result) {
    switch (result.toLowerCase()) {
      case 'positive':
        return Colors.red;
      case 'negative':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'inconclusive':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _editMember() {
    Navigator.pushNamed(context, '/edit-household-member', arguments: widget.member);
  }

  void _startNewScreening() {
    Navigator.pushNamed(context, '/contact-screening', arguments: {
      'memberInfo': {
        'name': widget.member.name,
        'age': widget.member.age,
        'gender': widget.member.gender,
        'relationship': widget.member.relationship,
        'phone': widget.member.phone,
        'screened': widget.member.screened,
        'screeningStatus': widget.member.screeningStatus,
        'lastScreeningDate': widget.member.lastScreeningDate,
      },
      'patientId': widget.patientId,
      'householdId': widget.householdId,
    });
  }

  void _callMember() {
    if (widget.member.phone != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Calling ${widget.member.name}...',
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

  void _handleMenuAction(String action) {
    switch (action) {
      case 'new_screening':
        _startNewScreening();
        break;
      case 'call_member':
        _callMember();
        break;
      case 'export_history':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Export feature coming soon!',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
        break;
    }
  }
}