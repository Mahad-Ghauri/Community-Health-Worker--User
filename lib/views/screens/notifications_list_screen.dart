// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:chw_tb/controllers/providers/secondary_providers.dart';
import 'package:chw_tb/models/core_models.dart';
import 'package:chw_tb/config/theme.dart';

class NotificationsListScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;

  const NotificationsListScreen({super.key, this.onMenuPressed});

  @override
  State<NotificationsListScreen> createState() =>
      _NotificationsListScreenState();
}

class _NotificationsListScreenState extends State<NotificationsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load notifications when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _markAllAsRead() {
    // Mark all unread notifications as read
    final provider = context.read<NotificationProvider>();
    for (final notification in provider.notifications) {
      if (notification.status == 'unread') {
        provider.markAsRead(notification.notificationId);
      }
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'refresh':
        context.read<NotificationProvider>().loadNotifications();
        break;
      case 'settings':
        _showNotificationSettings();
        break;
    }
  }

  void _showNotificationSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Notification Settings', style: GoogleFonts.poppins()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text('Patient Updates', style: GoogleFonts.poppins()),
              value: true,
              onChanged: (value) {},
            ),
            SwitchListTile(
              title: Text('Medication Reminders', style: GoogleFonts.poppins()),
              value: true,
              onChanged: (value) {},
            ),
            SwitchListTile(
              title: Text('System Alerts', style: GoogleFonts.poppins()),
              value: true,
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, child) {
        // Filter notifications for tabs
        final allNotifications = notificationProvider.notifications;
        final unreadNotifications = allNotifications
            .where((n) => n.status == 'unread')
            .toList();
        final highPriorityNotifications = allNotifications
            .where((n) => n.priority == 'high' || n.priority == 'urgent')
            .toList();

        return Scaffold(
          backgroundColor: MadadgarTheme.backgroundColor,
          appBar: AppBar(
            title: Text(
              'Notifications',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: MadadgarTheme.primaryColor,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: IconButton(
              onPressed: widget.onMenuPressed,
              icon: const Icon(Icons.menu),
              tooltip: 'Menu',
            ),
            actions: [
              IconButton(
                onPressed: () => _markAllAsRead(),
                icon: const Icon(Icons.done_all),
                tooltip: 'Mark All Read',
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: _handleMenuAction,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        const Icon(Icons.refresh),
                        const SizedBox(width: 8),
                        Text('Refresh', style: GoogleFonts.poppins()),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        const Icon(Icons.settings),
                        const SizedBox(width: 8),
                        Text('Settings', style: GoogleFonts.poppins()),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              tabs: [
                Tab(
                  child: Row(
                    children: [
                      const Icon(Icons.notifications, size: 18),
                      // const SizedBox(width: 4),
                      Expanded(
                        // ✅ fits text inside available space
                        child: Text(
                          'All (${allNotifications.length})',
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 8, color: Colors.orange),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Unread (${unreadNotifications.length})',
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.priority_high,
                        size: 18,
                        color: Colors.red,
                      ),
                      // const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Priority (${highPriorityNotifications.length})',
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: notificationProvider.isLoading
              ? const _NotificationListSkeleton()
              : notificationProvider.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: MadadgarTheme.errorColor.withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error_outline,
                          size: 36,
                          color: MadadgarTheme.errorColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading notifications',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notificationProvider.error!,
                        style: GoogleFonts.poppins(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () =>
                            notificationProvider.loadNotifications(),
                        icon: const Icon(Icons.refresh),
                        label: Text('Retry', style: GoogleFonts.poppins()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MadadgarTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildNotificationsList(allNotifications),
                    _buildNotificationsList(unreadNotifications),
                    _buildNotificationsList(highPriorityNotifications),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildNotificationsList(List<CHWNotification> notifications) {
    if (notifications.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<NotificationProvider>().loadNotifications();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          return _buildNotificationItem(notifications[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: MadadgarTheme.primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none,
              size: 36,
              color: MadadgarTheme.primaryColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All caught up! Check back later for updates.',
            style: GoogleFonts.poppins(color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(CHWNotification notification) {
    final isUnread = notification.status == 'unread';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread
              ? MadadgarTheme.primaryColor.withOpacity(0.25)
              : MadadgarTheme.primaryColor.withOpacity(0.06),
          width: 1,
        ),
        boxShadow: isUnread ? MadadgarTheme.shadowMd : MadadgarTheme.shadowSm,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleNotificationTap(notification),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildNotificationIcon(notification.type),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification.title,
                                  style: GoogleFonts.poppins(
                                    fontWeight: isUnread
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (isUnread)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: MadadgarTheme.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildPriorityChip(notification.priority),
                              const SizedBox(width: 8),
                              Text(
                                _formatTimestamp(notification.sentAt),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  notification.message,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
                if (notification.relatedId != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () =>
                            _handleNotificationAction(notification),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: Text(
                          'View Details',
                          style: GoogleFonts.poppins(),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: MadadgarTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'new_assignment':
        icon = Icons.person_add;
        color = Colors.blue;
        break;
      case 'reminder':
        icon = Icons.alarm;
        color = Colors.orange;
        break;
      case 'missed_followup':
        icon = Icons.event_busy;
        color = Colors.red;
        break;
      case 'emergency_alert':
        icon = Icons.warning;
        color = Colors.red;
        break;
      case 'system_update':
        icon = Icons.system_update;
        color = Colors.purple;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.grey;
    }

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildPriorityChip(String priority) {
    Color color;
    String label;

    switch (priority) {
      case 'urgent':
        color = Colors.red;
        label = 'URGENT';
        break;
      case 'high':
        color = Colors.orange;
        label = 'HIGH';
        break;
      case 'medium':
        color = Colors.blue;
        label = 'MEDIUM';
        break;
      case 'low':
        color = Colors.green;
        label = 'LOW';
        break;
      default:
        color = Colors.grey;
        label = 'NORMAL';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _handleNotificationTap(CHWNotification notification) {
    // Mark as read when tapped
    if (notification.status == 'unread') {
      context.read<NotificationProvider>().markAsRead(
        notification.notificationId,
      );
    }

    // Handle different notification types
    _handleNotificationAction(notification);
  }

  void _handleNotificationAction(CHWNotification notification) {
    switch (notification.type) {
      case 'new_assignment':
        _navigateToPatientDetails(notification);
        break;
      case 'reminder':
        _navigateToMedicationReminder(notification);
        break;
      case 'missed_followup':
        _navigateToPatientDetails(notification);
        break;
      case 'emergency_alert':
        _showEmergencyDetails(notification);
        break;
      case 'system_update':
        _showSystemUpdate(notification);
        break;
      default:
        _showNotificationDetails(notification);
    }
  }

  void _navigateToPatientDetails(CHWNotification notification) {
    if (notification.relatedId != null) {
      Navigator.pushNamed(
        context,
        '/patient-details',
        arguments: {
          'patientId': notification.relatedId,
          'fromNotification': true,
        },
      );
    }
  }

  void _navigateToMedicationReminder(CHWNotification notification) {
    if (notification.relatedId != null) {
      Navigator.pushNamed(
        context,
        '/adherence-tracking',
        arguments: {
          'patientId': notification.relatedId,
          'fromNotification': true,
        },
      );
    }
  }

  void _showEmergencyDetails(CHWNotification notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 8),
            Text('Emergency Alert', style: GoogleFonts.poppins()),
          ],
        ),
        content: Text(notification.message, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Understood', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _showSystemUpdate(CHWNotification notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Colors.blue),
            const SizedBox(width: 8),
            Text('System Update', style: GoogleFonts.poppins()),
          ],
        ),
        content: Text(notification.message, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _showNotificationDetails(CHWNotification notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title, style: GoogleFonts.poppins()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.message, style: GoogleFonts.poppins()),
            const SizedBox(height: 12),
            Text(
              'Received: ${_formatTimestamp(notification.sentAt)}',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),
            if (notification.readAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Read: ${_formatTimestamp(notification.readAt!)}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }
}

/// Loading skeleton mirroring the notification list — pulsing card
/// placeholders instead of a bare centered spinner.
class _NotificationListSkeleton extends StatefulWidget {
  const _NotificationListSkeleton();

  @override
  State<_NotificationListSkeleton> createState() =>
      _NotificationListSkeletonState();
}

class _NotificationListSkeletonState extends State<_NotificationListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.45,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => Container(
          height: 120,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: MadadgarTheme.primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
