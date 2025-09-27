// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:chw_tb/config/theme.dart';
import 'package:chw_tb/controllers/providers/patient_provider.dart';
import 'package:chw_tb/models/core_models.dart';

class VisitListScreen extends StatefulWidget {
  const VisitListScreen({super.key});

  @override
  State<VisitListScreen> createState() => _VisitListScreenState();
}

class _VisitListScreenState extends State<VisitListScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  String _selectedView = 'list'; // list, calendar, map
  String _selectedFilter = 'all';

  final List<String> _filterOptions = [
    'all',
    'today',
    'this_week',
    'completed',
    'scheduled',
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
    _tabController = TabController(length: 3, vsync: this);
    _fadeController.forward();

    // Initialize visit data when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final visitProvider = Provider.of<VisitProvider>(context, listen: false);
      visitProvider.initialize();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  String _getFilterDisplayName(String filter) {
    switch (filter) {
      case 'all':
        return 'All Visits';
      case 'today':
        return 'Today';
      case 'this_week':
        return 'This Week';
      case 'completed':
        return 'Completed';
      case 'scheduled':
        return 'Scheduled';
      default:
        return 'All Visits';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<VisitProvider, PatientProvider>(
      builder: (context, visitProvider, patientProvider, child) {
        return Scaffold(
          backgroundColor: MadadgarTheme.backgroundColor,
          appBar: AppBar(
            title: Text(
              'Visits',
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
                onPressed: _showFilterDialog,
                icon: const Icon(Icons.filter_list),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => setState(() => _selectedView = value),
                icon: const Icon(Icons.view_module),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'list',
                    child: Row(
                      children: [
                        Icon(Icons.list, color: MadadgarTheme.primaryColor),
                        const SizedBox(width: 8),
                        const Text('List View'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'calendar',
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: MadadgarTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        const Text('Calendar View'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'map',
                    child: Row(
                      children: [
                        Icon(Icons.map, color: MadadgarTheme.primaryColor),
                        const SizedBox(width: 8),
                        const Text('Map View'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.7),
              indicatorColor: Colors.white,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'All Visits'),
                Tab(text: 'Completed'),
                Tab(text: 'Scheduled'),
              ],
            ),
          ),
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Filter chip
                if (_selectedFilter != 'all') _buildActiveFilterChip(),

                // Content based on selected view
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildVisitContent('all', visitProvider, patientProvider),
                      _buildVisitContent(
                        'completed',
                        visitProvider,
                        patientProvider,
                      ),
                      _buildVisitContent(
                        'scheduled',
                        visitProvider,
                        patientProvider,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.pushNamed(context, '/new-visit'),
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

  Widget _buildActiveFilterChip() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: MadadgarTheme.primaryColor.withOpacity(0.1),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: MadadgarTheme.primaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.filter_alt, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  _getFilterDisplayName(_selectedFilter),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => setState(() => _selectedFilter = 'all'),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitContent(
    String tabType,
    VisitProvider visitProvider,
    PatientProvider patientProvider,
  ) {
    switch (_selectedView) {
      case 'calendar':
        return _buildCalendarView(tabType);
      case 'map':
        return _buildMapView(tabType);
      default:
        return _buildListView(tabType, visitProvider, patientProvider);
    }
  }

  Widget _buildListView(
    String tabType,
    VisitProvider visitProvider,
    PatientProvider patientProvider,
  ) {
    // Filter visits based on tab type and current filter
    List<Visit> filteredVisits = _getFilteredVisits(
      visitProvider.visits,
      tabType,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Visit count header
          Row(
            children: [
              Text(
                _getTabTitle(tabType),
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
                  color: MadadgarTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  visitProvider.isLoading
                      ? 'Loading...'
                      : '${filteredVisits.length} visits',
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

          // Visit list or empty state
          Expanded(
            child: visitProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredVisits.isEmpty
                ? _buildEmptyState(tabType)
                : ListView.builder(
                    itemCount: filteredVisits.length,
                    itemBuilder: (context, index) {
                      final visit = filteredVisits[index];
                      final patient = patientProvider.patients
                          .where((p) => p.patientId == visit.patientId)
                          .firstOrNull;
                      return _buildVisitCard(visit, patient);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Helper method to filter visits based on tab type and date filters
  List<Visit> _getFilteredVisits(List<Visit> visits, String tabType) {
    DateTime now = DateTime.now();

    List<Visit> filtered = visits
        .where((visit) {
          // Apply tab type filter
          switch (tabType) {
            case 'completed':
              return visit.found; // Assuming completed means patient was found
            case 'scheduled':
              return !visit.found; // Assuming scheduled means not completed yet
            default: // 'all'
              return true;
          }
        })
        .where((visit) {
          // Apply date filter
          switch (_selectedFilter) {
            case 'today':
              return visit.date.year == now.year &&
                  visit.date.month == now.month &&
                  visit.date.day == now.day;
            case 'this_week':
              DateTime weekStart = now.subtract(
                Duration(days: now.weekday - 1),
              );
              DateTime weekEnd = weekStart.add(Duration(days: 6));
              return visit.date.isAfter(
                    weekStart.subtract(Duration(days: 1)),
                  ) &&
                  visit.date.isBefore(weekEnd.add(Duration(days: 1)));
            case 'completed':
              return visit.found;
            case 'scheduled':
              return !visit.found;
            default: // 'all'
              return true;
          }
        })
        .toList();

    // Sort by date (newest first)
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  // Build empty state widget
  Widget _buildEmptyState(String tabType) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getTabIcon(tabType), size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No ${_getTabTitle(tabType)} Found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getEmptyMessage(tabType),
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/new-visit'),
            icon: const Icon(Icons.add_location),
            label: Text(
              'Schedule Visit',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: MadadgarTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build individual visit card
  Widget _buildVisitCard(Visit visit, Patient? patient) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navigate to visit details
          Navigator.pushNamed(
            context,
            '/visit-details',
            arguments: visit.visitId,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Visit type icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getVisitTypeColor(
                        visit.visitType,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getVisitTypeIcon(visit.visitType),
                      color: _getVisitTypeColor(visit.visitType),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Visit info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient?.name ?? 'Unknown Patient',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          _formatVisitType(visit.visitType),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status indicator and action button
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: visit.found
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          visit.found ? 'Completed' : 'Scheduled',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: visit.found
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                      ),
                      if (!visit.found) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/complete-visit',
                              arguments: visit.visitId,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: MadadgarTheme.primaryColor.withOpacity(
                                0.1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 12,
                                  color: MadadgarTheme.primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Complete',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: MadadgarTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Date and location
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(visit.date),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.location_on,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      patient?.address ?? 'Location not available',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (visit.notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  visit.notes,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods for visit card styling
  IconData _getVisitTypeIcon(String visitType) {
    switch (visitType.toLowerCase()) {
      case 'home_visit':
        return Icons.home;
      case 'follow_up':
        return Icons.schedule;
      case 'tracing':
        return Icons.search;
      case 'medicine_delivery':
        return Icons.local_pharmacy;
      case 'counseling':
        return Icons.chat_bubble;
      default:
        return Icons.location_on;
    }
  }

  Color _getVisitTypeColor(String visitType) {
    switch (visitType.toLowerCase()) {
      case 'home_visit':
        return Colors.blue;
      case 'follow_up':
        return Colors.green;
      case 'tracing':
        return Colors.orange;
      case 'medicine_delivery':
        return Colors.purple;
      case 'counseling':
        return Colors.teal;
      default:
        return MadadgarTheme.primaryColor;
    }
  }

  String _formatVisitType(String visitType) {
    switch (visitType.toLowerCase()) {
      case 'home_visit':
        return 'Home Visit';
      case 'follow_up':
        return 'Follow-up';
      case 'tracing':
        return 'Contact Tracing';
      case 'medicine_delivery':
        return 'Medicine Delivery';
      case 'counseling':
        return 'Counseling';
      default:
        return visitType.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final visitDate = DateTime(date.year, date.month, date.day);

    if (visitDate == today) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (visitDate == today.subtract(Duration(days: 1))) {
      return 'Yesterday ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildCalendarView(String tabType) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Calendar header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    'September 2025',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Calendar placeholder
          Expanded(
            child: Card(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month,
                      size: 80,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Calendar View',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Calendar integration will be implemented with visit data',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
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

  Widget _buildMapView(String tabType) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Map controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.my_location,
                          color: MadadgarTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'My Location',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.layers)),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.fullscreen),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Map placeholder
          Expanded(
            child: Card(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Map View',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Map integration will show visit locations and routes',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
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

  String _getTabTitle(String tabType) {
    switch (tabType) {
      case 'completed':
        return 'Completed Visits';
      case 'scheduled':
        return 'Scheduled Visits';
      default:
        return 'All Visits';
    }
  }

  IconData _getTabIcon(String tabType) {
    switch (tabType) {
      case 'completed':
        return Icons.check_circle_outline;
      case 'scheduled':
        return Icons.schedule;
      default:
        return Icons.home_outlined;
    }
  }

  String _getEmptyMessage(String tabType) {
    switch (tabType) {
      case 'completed':
        return 'No completed visits yet.\nStart visiting patients to see them here.';
      case 'scheduled':
        return 'No scheduled visits.\nSchedule visits to keep track of appointments.';
      default:
        return 'No visits recorded.\nStart by scheduling your first visit.';
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter Visits',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._filterOptions.map((filter) => _buildFilterOption(filter)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MadadgarTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Apply Filter',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String filter) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = filter);
        Navigator.pop(context);
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
}
