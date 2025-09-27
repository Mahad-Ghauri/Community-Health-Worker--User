// ignore_for_file: deprecated_member_use, avoid_print

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:chw_tb/config/theme.dart';
import 'package:chw_tb/controllers/providers/patient_provider.dart';
import 'package:chw_tb/controllers/providers/app_providers.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimations();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load all necessary data for dashboard
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      final visitProvider = Provider.of<VisitProvider>(context, listen: false);
      final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
      
      // Initialize providers
      await Future.wait([
        patientProvider.initialize(),
        visitProvider.initialize(),
        appStateProvider.initialize(),
      ]);
      
    } catch (e) {
      print('Error loading dashboard data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
  }

  void _startAnimations() {
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
  }

  String _formatSyncTime(DateTime? lastSync) {
    if (lastSync == null) return 'Never';
    
    final now = DateTime.now();
    final difference = now.difference(lastSync);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MadadgarTheme.backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer4<PatientProvider, VisitProvider, AppStateProvider, AuthProvider>(
              builder: (context, patientProvider, visitProvider, appStateProvider, authProvider, child) {
                return SafeArea(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        // Header with user info and sync status
                        _buildHeader(appStateProvider, authProvider),
                        
                        // Main dashboard content
                        Expanded(
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Quick stats cards
                                  _buildQuickStatsSection(patientProvider, visitProvider),
                                  
                                  const SizedBox(height: 24),
                                  
                                  // Quick actions grid
                                  _buildQuickActionsSection(),
                                  
                                  const SizedBox(height: 24),
                                  
                                  // Recent activity
                                  _buildRecentActivitySection(visitProvider, patientProvider),
                                  
                                
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildHeader(AppStateProvider appStateProvider, AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MadadgarTheme.primaryColor, MadadgarTheme.primaryColor.withOpacity(0.8)],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // User avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              
              // User greeting
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    Text(
                      authProvider.chwUser?.name ?? 'CHW User',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Notification bell
             
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Sync status bar
          _buildSyncStatusBar(appStateProvider),
        ],
      ),
    );
  }

  Widget _buildSyncStatusBar(AppStateProvider appStateProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            appStateProvider.isOnline ? Icons.cloud_done : Icons.cloud_off,
            color: appStateProvider.isOnline ? Colors.green : Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            appStateProvider.isOnline 
                ? 'Online • Last sync: ${_formatSyncTime(appStateProvider.lastSyncTime)}' 
                : 'Offline mode',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsSection(PatientProvider patientProvider, VisitProvider visitProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Overview',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Total Patients',
                value: patientProvider.patients.length.toString(),
                icon: Icons.people_outline,
                color: MadadgarTheme.primaryColor,
                onTap: () => Navigator.pushNamed(context, '/patients'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'Recent Visits',
                value: visitProvider.recentVisits.length.toString(),
                icon: Icons.home_outlined,
                color: MadadgarTheme.secondaryColor,
                onTap: () => Navigator.pushNamed(context, '/visits'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shadowColor: color.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: color,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            _buildActionCard(
              title: 'Register Patient',
              icon: Icons.person_add,
              color: MadadgarTheme.primaryColor,
              onTap: () => Navigator.pushNamed(context, '/register-patient'),
            ),
            _buildActionCard(
              title: 'New Visit',
              icon: Icons.add_location,
              color: MadadgarTheme.secondaryColor,
              onTap: () => Navigator.pushNamed(context, '/new-visit'),
            ),
            _buildActionCard(
              title: 'Search Patients',
              icon: Icons.search,
              color: MadadgarTheme.accentColor,
              onTap: () => Navigator.pushNamed(context, '/search-patients'),
            ),
            _buildActionCard(
              title: 'View Reports',
              icon: Icons.analytics,
              color: MadadgarTheme.primaryColor.withOpacity(0.8),
              onTap: () => Navigator.pushNamed(context, '/reports'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 32,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection(VisitProvider visitProvider, PatientProvider patientProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/visits'),
              child: Text(
                'View All',
                style: GoogleFonts.poppins(
                  color: MadadgarTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: _buildRecentActivityItems(visitProvider, patientProvider),
          ),
        ),
      ],
    );
  }

  // Build dynamic recent activity items from real data
  List<Widget> _buildRecentActivityItems(VisitProvider visitProvider, PatientProvider patientProvider) {
    List<Widget> items = [];
    
    // Get recent visits (last 5)
    final recentVisits = visitProvider.recentVisits.take(3).toList();
    
    // Get recently registered patients (last 2)
    final recentPatients = patientProvider.patients
        .where((p) => DateTime.now().difference(p.createdAt).inDays <= 7)
        .take(2)
        .toList();
    
    // Add recent visits
    for (int i = 0; i < recentVisits.length; i++) {
      final visit = recentVisits[i];
      final patient = patientProvider.patients
          .where((p) => p.patientId == visit.patientId)
          .firstOrNull;
      
      if (patient != null) {
        items.add(_buildActivityItem(
          title: 'Visit to ${patient.name}',
          subtitle: '${_formatVisitType(visit.visitType)} • ${_formatTimeAgo(visit.date)}',
          icon: visit.found ? Icons.check_circle : Icons.schedule,
          color: visit.found ? Colors.green : Colors.orange,
        ));
        
        if (i < recentVisits.length - 1 || recentPatients.isNotEmpty) {
          items.add(const Divider(height: 1));
        }
      }
    }
    
    // Add recent patient registrations
    for (int i = 0; i < recentPatients.length; i++) {
      final patient = recentPatients[i];
      items.add(_buildActivityItem(
        title: 'New patient registered',
        subtitle: '${patient.name} • ${_formatTimeAgo(patient.createdAt)}',
        icon: Icons.person_add,
        color: MadadgarTheme.primaryColor,
      ));
      
      if (i < recentPatients.length - 1) {
        items.add(const Divider(height: 1));
      }
    }
    
    // If no recent activity, show placeholder
    if (items.isEmpty) {
      items.add(_buildActivityItem(
        title: 'No recent activity',
        subtitle: 'Start by registering patients or conducting visits',
        icon: Icons.info_outline,
        color: Colors.grey,
      ));
    }
    
    return items;
  }

  // Helper method to format visit types for display
  String _formatVisitType(String visitType) {
    switch (visitType.toLowerCase()) {
      case 'home_visit':
        return 'Home visit completed';
      case 'follow_up':
        return 'Follow-up completed';
      case 'tracing':
        return 'Contact tracing completed';
      case 'medicine_delivery':
        return 'Medicine delivery completed';
      case 'counseling':
        return 'Counseling session completed';
      default:
        return 'Visit completed';
    }
  }

  // Helper method to format time ago
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays > 0) {
      return difference.inDays == 1 ? 'Yesterday' : '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildActivityItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: Colors.black54,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.grey,
        size: 20,
      ),
    );
  }

  
  // Helper method to get time-based greeting
  String _getGreeting() {
    final hour = DateTime.now().hour;
    
    if (hour < 12) {
      return 'Good Morning!';
    } else if (hour < 17) {
      return 'Good Afternoon!';
    } else {
      return 'Good Evening!';
    }
  }
}
