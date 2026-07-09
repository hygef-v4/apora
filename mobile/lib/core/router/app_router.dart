import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth_profile/providers/auth_notifier.dart';
import '../../features/auth_profile/screens/change_password_screen.dart';
import '../../features/auth_profile/screens/forgot_password_screen.dart';
import '../../features/auth_profile/screens/login_screen.dart';
import '../../features/auth_profile/screens/profile_edit_screen.dart';
import '../../features/auth_profile/screens/profile_screen.dart';
import '../../features/home/screens/manager_shell.dart';
import '../../features/home/screens/resident_home_screen.dart';
import '../../features/home/screens/task_board_screen.dart';
import '../../features/home/screens/workspace_select_screen.dart';
import '../../features/management/screens/staff_detail_screen.dart';
import '../../features/management/screens/staff_edit_screen.dart';
import '../../features/management/screens/staff_form_screen.dart';
import '../../features/management/screens/staff_list_screen.dart';
import '../../features/billing/models/invoice.dart';
import '../../features/billing/models/payment.dart';
import '../../features/billing/screens/payment_webview.dart';
import '../../features/billing/screens/payment_receipt_screen.dart';
import '../../features/billing/screens/manager_generate_bill_screen.dart';
import '../../features/billing/screens/manager_invoice_list_screen.dart';
import '../../features/billing/screens/manager_pricing_settings_screen.dart';
import '../../features/roommate/screens/roommate_list_screen.dart';
import '../../features/roommate/screens/roommate_register_screen.dart';
import '../../features/roommate/screens/manager_roommate_list_screen.dart';
import '../../features/roommate/screens/manager_roommate_detail_screen.dart';
import '../../features/ticket/screens/ticket_list_screen.dart';
import '../../features/ticket/screens/ticket_create_screen.dart';

/// Đường dẫn route tập trung.
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String changePassword = '/change-password';
  static const String profile = '/profile';
  static const String profileEdit = '/profile/edit';
  static const String residentHome = '/home';
  static const String dashboard = '/dashboard';
  static const String tasks = '/tasks';
  static const String selectWorkspace = '/select-workspace';

  // Module 8: Quản lý nhân viên (UC36-UC40)
  static const String staffList = '/staff';
  static const String staffCreate = '/staff/create';
  static String staffDetailPath(int id) => '/staff/$id';
  static String staffEditPath(int id) => '/staff/$id/edit';

  // Module 3: Hóa đơn (Manager)
  static const String generateBill = '/manager/bills/generate';
  static const String managerInvoiceList = '/manager/bills';
  static const String pricingSettings = '/manager/pricing-settings';

  // Module 2: Thành viên phòng (UC10-UC12)
  static const String roommates = '/resident/roommates';
  static const String roommateRegister = '/resident/roommates/register';
  static const String managerRoommates = '/manager/roommates';

  // Module 4: Sự cố & Công việc (UC18-UC23)
  static const String tickets = '/tickets';
  static const String ticketCreate = '/tickets/create';
}

/// Xác định màn hình chính theo role (UC01 bước 4):
/// Resident -> Home, Landlord/Manager -> Dashboard, Staff -> Task List.
/// User giữ nhiều nhóm role -> màn chọn workspace.
String homePathForRoles(List<String> roles) {
  final isManagement = roles.contains('LANDLORD') || roles.contains('MANAGER');
  final isResident = roles.contains('RESIDENT');
  final isStaff = roles.contains('SECURITY_GUARD') ||
      roles.contains('JANITOR') ||
      roles.contains('TECHNICIAN');

  final groupCount = [isManagement, isResident, isStaff].where((x) => x).length;
  if (groupCount > 1) return AppRoutes.selectWorkspace;
  if (isManagement) return AppRoutes.dashboard;
  if (isStaff) return AppRoutes.tasks;
  return AppRoutes.residentHome;
}

final routerProvider = Provider<GoRouter>((ref) {
  // Bridge AuthState -> Listenable để GoRouter re-evaluate redirect khi auth đổi.
  final authListenable = ValueNotifier<AuthState>(ref.read(authNotifierProvider));
  ref
    ..onDispose(authListenable.dispose)
    ..listen(authNotifierProvider, (_, next) => authListenable.value = next);

  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: authListenable,
    redirect: (context, state) {
      final auth = authListenable.value;
      final location = state.matchedLocation;
      final isAuthRoute =
          location == AppRoutes.login || location == AppRoutes.forgotPassword;

      // Chưa đăng nhập -> chỉ được vào Login / Forgot Password
      if (!auth.isAuthenticated) {
        return isAuthRoute ? null : AppRoutes.login;
      }

      // BR-01: đang dùng mật khẩu mặc định -> ép vào màn đổi mật khẩu
      if (auth.mustChangePassword) {
        return location == AppRoutes.changePassword ? null : AppRoutes.changePassword;
      }

      // Đã đăng nhập mà đứng ở màn auth -> đưa về home theo role
      if (isAuthRoute || location == AppRoutes.changePassword) {
        return homePathForRoles(auth.roles);
      }

      // Module 8: chỉ MANAGER/LANDLORD được vào màn quản lý nhân viên
      // (backend vẫn enforce 403 - đây là chặn sớm phía client cho UX)
      final isManagement =
          auth.roles.contains('MANAGER') || auth.roles.contains('LANDLORD');
      if (location.startsWith(AppRoutes.staffList) && !isManagement) {
        return homePathForRoles(auth.roles);
      }
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.changePassword,
        builder: (_, _) => const ChangePasswordScreen(),
      ),
      GoRoute(path: AppRoutes.profile, builder: (_, _) => const ProfileScreen()),
      GoRoute(
        path: AppRoutes.profileEdit,
        builder: (_, _) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: AppRoutes.residentHome,
        builder: (_, _) => const ResidentHomeScreen(),
      ),
      GoRoute(path: AppRoutes.dashboard, builder: (_, _) => const ManagerShell()),
      GoRoute(path: AppRoutes.tasks, builder: (_, _) => const TaskBoardScreen()),
      GoRoute(
        path: AppRoutes.selectWorkspace,
        builder: (_, _) => const WorkspaceSelectScreen(),
      ),
      // Module 8: Quản lý nhân viên (chỉ MANAGER/LANDLORD - backend enforce 403)
      GoRoute(path: AppRoutes.staffList, builder: (_, _) => const StaffListScreen()),
      GoRoute(
        path: AppRoutes.staffCreate,
        builder: (_, _) => const StaffFormScreen(),
      ),
      GoRoute(
        path: '/staff/:id',
        builder: (_, state) => StaffDetailScreen(
          staffId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/staff/:id/edit',
        builder: (_, state) => StaffEditScreen(
          staffId: int.parse(state.pathParameters['id']!),
        ),
      ),
      // Module 3: Hóa đơn & Thanh toán (UC15 - UC17)
      GoRoute(
        path: '/invoices/pay',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {
            'invoiceId': 101,
            'paymentUrl': 'https://pay.payos.vn/web/checkout/MOCK_ORDER_101',
            'totalAmount': 5190000.0,
          };
          return PaymentWebView(
            invoiceId: extra['invoiceId'] as int,
            paymentUrl: extra['paymentUrl'] as String,
            totalAmount: extra['totalAmount'] as double,
          );
        },
      ),
      GoRoute(
        path: '/invoices/receipt',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          final invoice = extra['invoice'] as Invoice;
          final payment = extra['payment'] as Payment;
          return PaymentReceiptScreen(
            invoice: invoice,
            payment: payment,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.generateBill,
        builder: (context, state) => const ManagerGenerateBillScreen(),
      ),
      GoRoute(
        path: AppRoutes.managerInvoiceList,
        builder: (context, state) => const ManagerInvoiceListScreen(),
      ),
      GoRoute(
        path: AppRoutes.pricingSettings,
        builder: (context, state) => const ManagerPricingSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.roommates,
        builder: (context, state) => const RoommateListScreen(),
      ),
      GoRoute(
        path: AppRoutes.roommateRegister,
        builder: (context, state) => const RoommateRegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.managerRoommates,
        builder: (context, state) => const RoommateApprovalListScreen(),
      ),
      GoRoute(
        path: '/manager/roommates/:id',
        builder: (context, state) => RoommateApprovalDetailScreen(
          roommateId: int.parse(state.pathParameters['id']!),
        ),
      ),
      // Module 4: Sự cố & Công việc (UC18-UC23)
      GoRoute(
        path: AppRoutes.ticketCreate,
        builder: (context, state) => const TicketCreateScreen(),
      ),
      GoRoute(
        path: AppRoutes.tickets,
        builder: (context, state) => const TicketListScreen(),
      ),
    ],
  );
});
