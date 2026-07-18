// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:chw_tb/config/theme.dart';
import 'package:chw_tb/views/screens/dashboard_screen.dart';
import 'package:chw_tb/views/screens/patient_list_screen.dart';
import 'package:chw_tb/views/screens/visit_list_screen.dart';
import 'package:chw_tb/views/screens/notifications_list_screen.dart';
import 'package:chw_tb/controllers/services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:chw_tb/controllers/providers/app_providers.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<NavigationItem> get _navigationItems => [
    NavigationItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      screen: DashboardScreen(onMenuPressed: _openDrawer),
    ),
    NavigationItem(
      label: 'Patients',
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      screen: PatientListScreen(onMenuPressed: _openDrawer),
    ),
    NavigationItem(
      label: 'Visits',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      screen: VisitListScreen(onMenuPressed: _openDrawer),
    ),
    NavigationItem(
      label: 'Notifications',
      icon: Icons.notifications_outlined,
      activeIcon: Icons.notifications,
      screen: NotificationsListScreen(onMenuPressed: _openDrawer),
    ),
  ];

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      // Let page content extend behind the floating nav so the
      // glass blur has real content to diffuse.
      extendBody: true,
      drawer: _buildNavigationDrawer(),
      body: _navigationItems[_selectedIndex].screen,
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildBottomNavigation() {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          // Soft float shadow — carried outside the clip.
          boxShadow: MadadgarTheme.shadowLg,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              decoration: BoxDecoration(
                // Light frosted fill — lets the blur read as glass.
                color: Colors.white.withOpacity(0.65),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withOpacity(0.30),
                  width: 1,
                ),
              ),
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                backgroundColor: Colors.transparent,
                selectedItemColor: MadadgarTheme.primaryColor,
                unselectedItemColor: Colors.grey.shade600,
                selectedLabelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                unselectedLabelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                ),
                elevation: 0,
                items: _navigationItems.map((item) {
                  final isSelected = _navigationItems[_selectedIndex] == item;
                  return BottomNavigationBarItem(
                    icon: Icon(isSelected ? item.activeIcon : item.icon),
                    label: item.label,
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationDrawer() {
    final authProvider = context.watch<AuthProvider>();
    return Drawer(
      child: Column(
        children: [
          // Header
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  MadadgarTheme.primaryColor,
                  MadadgarTheme.primaryColor.withOpacity(0.8),
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      authProvider.chwUser?.name ?? 'CHW User',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Menu items
          Expanded(
            child: Scrollbar(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    icon: Icons.dashboard_outlined,
                    title: 'Dashboard',
                    onTap: () {
                      Navigator.pop(context);
                      _onItemTapped(0);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.people_outline,
                    title: 'My Patients',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/patients');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.add_location,
                    title: 'New Visit',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/new-visit');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.person_add,
                    title: 'Register Patient',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/register-patient');
                    },
                  ),
                  const Divider(),
                  _buildDrawerItem(
                    icon: Icons.analytics_outlined,
                    title: 'Reports',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/reports');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.sync,
                    title: 'Sync Data',
                    onTap: () {
                      Navigator.pop(context);
                     Navigator.pushNamed(context, '/sync-status');
                    },
                  ),
                  const Divider(),
                  _buildDrawerItem(
                    icon: Icons.person_outline,
                    title: 'Profile',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/profile');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/settings');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.help_outline,
                    title: 'Help & FAQ',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/help');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.info_outline,
                    title: 'About',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/about');
                    },
                  ),
                  const SizedBox(height: 16), // Add some bottom padding
                ],
              ),
            ),
          ),

          // Logout
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showLogoutDialog(),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.logout,
                          color: MadadgarTheme.errorColor,
                          size: 24,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Logout',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              color: MadadgarTheme.errorColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: MadadgarTheme.primaryColor, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Logout',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.instance.signOut();
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/sign-in');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MadadgarTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: Text('Logout', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

}

class NavigationItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget screen;

  NavigationItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.screen,
  });
}
