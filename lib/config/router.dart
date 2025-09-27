import 'package:chw_tb/components/elegeant_route.dart';
import 'package:chw_tb/models/core_models.dart';
import 'package:flutter/material.dart';

// Core Screens
import '../views/screens/splash_screen.dart';
import '../views/screens/home_screen.dart';
import '../views/screens/dashboard_screen.dart';
import '../views/screens/main_navigation_screen.dart';

// Authentication Screens
import '../views/interface/authentication/sign_in_screen.dart';
import '../views/interface/authentication/sign_up_screen.dart';
import '../views/interface/authentication/forget_password.dart';

// Patient Management Screens
import '../views/screens/patient_list_screen.dart';
import '../views/screens/patient_details_screen.dart';
import '../views/screens/register_patient_screen.dart';
import '../views/screens/edit_patient_screen.dart';
import '../views/screens/household_members_screen.dart';
import '../views/screens/add_household_member_screen.dart';
import '../views/screens/household_member_details_screen.dart';

// Visit Management Screens
import '../views/screens/visit_list_screen.dart';
import '../views/screens/visit_details_screen.dart';
import '../views/screens/new_visit_screen.dart';
import '../views/screens/edit_visit_screen.dart';
import '../views/screens/complete_visit_screen.dart';

// Clinical Screens
import '../views/screens/contact_screening_screen.dart';
import '../views/screens/screening_results_screen.dart';
import '../views/screens/treatment_plan_screen.dart';
import '../views/screens/adherence_tracking_screen.dart';
import '../views/screens/pill_count_screen.dart';
import '../views/screens/side_effects_log_screen.dart';
import '../views/screens/missed_followup_alert_screen.dart';

// Notification Screens
import '../views/screens/notifications_list_screen.dart';
import '../views/screens/notifications_screen.dart';

// Settings & Profile Screens
import '../views/screens/profile_settings_screen.dart';
import '../views/screens/app_settings_screen.dart';

// Reports & Data Screens
import '../views/screens/reports_screen.dart';
import '../views/screens/sync_status_screen.dart';
import '../views/screens/offline_queue_screen.dart';

// Help & Support Screens
import '../views/screens/help_faq_screen.dart';
import '../views/screens/about_screen.dart';

class AppRouter {
  // Global navigator key to allow navigation outside of a BuildContext with a Navigator
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // =================== CORE NAVIGATION ===================
      case '/':
        return ElegantRoute.build(const SplashScreen());
      case '/main-navigation':
        return ElegantRoute.build(const MainNavigationScreen());
      case '/dashboard':
        return ElegantRoute.build(const DashboardScreen());
      case '/home':
        return ElegantRoute.build(const HomeScreen());

      // =================== AUTHENTICATION ===================
      case '/sign-in':
        return ElegantRoute.build(const SignInScreen());
      case '/sign-up':
        return ElegantRoute.build(const SignUpScreen());
      case '/forgot-password':
        return ElegantRoute.build(const ForgetPasswordScreen());

      // =================== PATIENT MANAGEMENT ===================
      case '/patients':
      case '/patient-list':
        return ElegantRoute.build(const PatientListScreen());
      case '/patient-details':
        final patientId = settings.arguments as String?;
        return ElegantRoute.build(PatientDetailsScreen(patientId: patientId));
      case '/register-patient':
        return ElegantRoute.build(const RegisterPatientScreen());
      case '/edit-patient':
        final args = settings.arguments;
        String? patientId;
        if (args is Map<String, dynamic>) {
          patientId = args['patientId'] as String?;
        } else if (args is String) {
          patientId = args;
        }
        return ElegantRoute.build(EditPatientScreen(patientId: patientId));
      case '/household-members':
        final patientId = settings.arguments as String?;
        return ElegantRoute.build(HouseholdMembersScreen(patientId: patientId));
      case '/add-household-member':
        String? patientId;
        String? householdId;

        if (settings.arguments != null) {
          final args = settings.arguments as Map<String, dynamic>?;
          patientId = args?['patientId'] as String?;
          householdId = args?['householdId'] as String?;
        }

        return ElegantRoute.build(
          AddHouseholdMemberScreen(
            patientId: patientId,
            householdId: householdId,
          ),
        );
      case '/household-member-details':
        final args = settings.arguments;

        if (args is HouseholdMember) {
          return ElegantRoute.build(HouseholdMemberDetailsScreen(member: args));
        } else if (args is Map<String, dynamic>) {
          final member = args['member'] as HouseholdMember?;
          final householdId = args['householdId'] as String?;
          final patientId = args['patientId'] as String?;

          if (member != null) {
            return ElegantRoute.build(
              HouseholdMemberDetailsScreen(
                member: member,
                householdId: householdId,
                patientId: patientId,
              ),
            );
          }
        }
        return ElegantRoute.build(
          Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(child: Text('Member data not provided')),
          ),
        );

      // =================== VISIT MANAGEMENT ===================
      case '/visits':
      case '/visit-list':
        return ElegantRoute.build(const VisitListScreen());
      case '/visit-details':
        final visitId = settings.arguments as String?;
        if (visitId != null) {
          return ElegantRoute.build(VisitDetailsScreen(visitId: visitId));
        }
        return ElegantRoute.build(
          Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(child: Text('Visit ID not provided')),
          ),
        );
      case '/new-visit':
        return ElegantRoute.build(const NewVisitScreen());
      case '/edit-visit':
        return ElegantRoute.build(const EditVisitScreen());
      case '/complete-visit':
        final visitId = settings.arguments as String?;
        if (visitId != null) {
          return ElegantRoute.build(CompleteVisitScreen(visitId: visitId));
        }
        return ElegantRoute.build(
          Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(child: Text('Visit ID not provided')),
          ),
        );

      // =================== CLINICAL WORKFLOWS ===================
      case '/contact-screening':
        String? patientId;
        String? householdId;
        Map<String, dynamic>? memberData;

        if (settings.arguments != null) {
          if (settings.arguments is Map<String, dynamic>) {
            final args = settings.arguments as Map<String, dynamic>;
            patientId = args['patientId'] as String?;
            householdId = args['householdId'] as String?;
            memberData = args['memberInfo'] as Map<String, dynamic>?;
          } else if (settings.arguments is HouseholdMember) {
            // Handle direct HouseholdMember object
            final member = settings.arguments as HouseholdMember;
            memberData = {
              'name': member.name,
              'age': member.age,
              'gender': member.gender,
              'relationship': member.relationship,
              'phone': member.phone,
              'screened': member.screened,
              'screeningStatus': member.screeningStatus,
              'lastScreeningDate': member.lastScreeningDate,
            };
            // Note: patientId and householdId will need to be passed separately
            // or retrieved from the calling screen context
          }
        }

        return ElegantRoute.build(
          ContactScreeningScreen(
            patientId: patientId,
            householdId: householdId,
            memberData: memberData,
          ),
        );
      case '/screening-results':
        return ElegantRoute.build(const ScreeningResultsScreen());
      case '/treatment-plan':
        return ElegantRoute.build(const TreatmentPlanScreen());
      case '/adherence-tracking':
        String? patientId;

        if (settings.arguments != null) {
          if (settings.arguments is Map<String, dynamic>) {
            final args = settings.arguments as Map<String, dynamic>;
            patientId = args['patientId'] as String?;
          } else if (settings.arguments is String) {
            patientId = settings.arguments as String;
          }
        }

        return ElegantRoute.build(
          AdherenceTrackingScreen(patientId: patientId),
        );
      case '/pill-count':
        return ElegantRoute.build(const PillCountScreen());
      case '/side-effects':
        return ElegantRoute.build(const SideEffectsLogScreen());
      case '/missed-followup':
        return ElegantRoute.build(const MissedFollowupAlertScreen());

      // =================== NOTIFICATIONS ===================
      case '/notifications':
        return ElegantRoute.build(const NotificationsScreen());
      case '/notifications-list':
        return ElegantRoute.build(const NotificationsListScreen());

      // =================== PROFILE & SETTINGS ===================

      case '/profile':
        return ElegantRoute.build(const ProfileSettingsScreen());
      case '/settings':
        return ElegantRoute.build(const AppSettingsScreen());

      // =================== REPORTS & DATA ===================
      case '/reports':
        return ElegantRoute.build(const ReportsScreen());
      case '/sync-status':
        return ElegantRoute.build(const SyncStatusScreen());
      case '/offline-queue':
        return ElegantRoute.build(const OfflineQueueScreen());

      // =================== HELP & SUPPORT ===================
      case '/help':
      case '/help-faq':
        return ElegantRoute.build(const HelpFaqScreen());
      case '/about':
        return ElegantRoute.build(const AboutScreen());

      // =================== 404 FALLBACK ===================
      default:
        return ElegantRoute.build(
          Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: const Text('Page Not Found'),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 100,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '404 - Page Not Found',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'The route "${settings.name}" does not exist.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () {
                        navigatorKey.currentState?.pushNamedAndRemoveUntil(
                          '/main-navigation',
                          (route) => false,
                        );
                      },
                      child: const Text('Go to Dashboard'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    }
  }
}
