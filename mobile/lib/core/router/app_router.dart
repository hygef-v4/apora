import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth_profile/providers/auth_notifier.dart';
import '../../features/auth_profile/screens/change_password_screen.dart';
import '../../features/auth_profile/screens/forgot_password_screen.dart';
import '../../features/auth_profile/screens/login_screen.dart';
import '../../features/auth_profile/screens/profile_edit_screen.dart';
import '../../features/auth_profile/screens/profile_screen.dart';
import '../../features/communication/screens/announce_form_screen.dart';
import '../../features/communication/screens/notification_detail_screen.dart';
import '../../features/communication/screens/notification_list_screen.dart';
import '../../features/home/screens/manager_shell.dart';
import '../../features/home/screens/resident_home_screen.dart';
import '../../features/home/screens/task_board_screen.dart';
import '../../features/home/screens/workspace_select_screen.dart';
import '../../features/management/screens/manager_detail_screen.dart';
import '../../features/management/screens/manager_form_screen.dart';
import '../../features/management/screens/manager_list_screen.dart';
import '../../features/management/screens/staff_detail_screen.dart';
import '../../features/management/screens/staff_edit_screen.dart';
import '../../features/management/screens/staff_form_screen.dart';
import '../../features/management/screens/staff_list_screen.dart';
import '../../features/management/screens/apartment_list_screen.dart';
import '../../features/management/screens/apartment_detail_screen.dart';
import '../../features/management/screens/apartment_form_screen.dart';
import '../../features/management/screens/apartment_checkin_screen.dart';
import '../../features/management/screens/apartment_checkout_screen.dart';
import '../../features/management/models/apartment.dart';
import '../../features/management/providers/apartment_notifier.dart';
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
import '../../features/contract/models/contract.dart';
import '../../features/contract/screens/contract_list_screen.dart';
import '../../features/contract/screens/contract_screen.dart';
import '../../features/contract/screens/extension_list_screen.dart';
import '../../features/contract/screens/extension_review_screen.dart';
import '../../features/contract/screens/request_extension_screen.dart';
import '../../features/ticket/models/ticket.dart';
import '../../features/ticket/screens/assign_task_screen.dart';
import '../../features/ticket/screens/task_detail_screen.dart';
import '../../features/ticket/screens/ticket_list_screen.dart';
import '../../features/ticket/screens/ticket_create_screen.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/ticket/screens/ticket_detail_screen.dart';

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

  // Module 9: Quản lý Manager (UC41-UC42)
  static const String managerList = '/managers';
  static const String managerCreate = '/managers/create';
  static String managerDetailPath(int id) => '/managers/$id';
  static String managerEditPath(int id) => '/managers/$id/edit';

  // Module 3: Hóa đơn (Manager)
  static const String generateBill = '/manager/bills/generate';
  static const String managerInvoiceList = '/manager/bills';
  static const String pricingSettings = '/manager/pricing-settings';

  // Module Communication
  static const String announce = '/manager/announce';
  static const String notifications = '/notifications';
  static const String notificationDetail = '/notifications/detail';

  // Module Chat
  static const String chatList = '/manager/chat';
  static const String chatResident = '/resident/chat';
  static String chatDetailPath(int id) => '/manager/chat/$id';

  // Module 2: Thành viên phòng (UC10-UC12)
  static const String roommates = '/resident/roommates';
  static const String roommateRegister = '/resident/roommates/register';
  static const String managerRoommates = '/manager/roommates';

  // Module 6: Quản lý Căn hộ (UC29-UC32)
  static const String apartmentList = '/manager/apartments';
  static const String apartmentCreate = '/manager/apartments/create';
  static String apartmentDetailPath(int id) => '/manager/apartments/$id';
  static String apartmentEditPath(int id) => '/manager/apartments/$id/edit';
  static String apartmentCheckinPath(int id) => '/manager/apartments/$id/checkin';
  static String apartmentCheckoutPath(int id) => '/manager/apartments/$id/checkout';

  // Module 2: Hợp đồng & Gia hạn lưu trú (UC06-UC09)
  static const String myContract = '/contract';
  static const String requestExtension = '/contract/extend';
  static const String contractList = '/manager/contracts';
  static const String extensionList = '/manager/extensions';
  static String extensionDetailPath(int id) => '/manager/extensions/$id';

  // Module 4: Sự cố & Công việc (UC18-UC23)
  static const String tickets = '/tickets';
  static const String ticketCreate = '/tickets/create';
  static String ticketDetailPath(int id) => '/tickets/$id';
  static String ticketAssignPath(int id) => '/tickets/$id/assign';
  static String taskDetailPath(int id) => '/tasks/$id';
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

      // Module 9: chỉ LANDLORD được vào màn quản lý Manager (BR-60)
      final isLandlord = auth.roles.contains('LANDLORD');
      if (location.startsWith(AppRoutes.managerList) && !isLandlord) {
        return homePathForRoles(auth.roles);
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) {
          final auth = authListenable.value;
          return auth.isAuthenticated ? homePathForRoles(auth.roles) : AppRoutes.login;
        },
      ),
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
      // Module 9: Quản lý Manager (chỉ LANDLORD - backend enforce 403, BR-60)
      GoRoute(
        path: AppRoutes.managerList,
        builder: (_, _) => const ManagerListScreen(),
      ),
      GoRoute(
        path: AppRoutes.managerCreate,
        builder: (_, _) => const ManagerFormScreen(),
      ),
      GoRoute(
        path: '/managers/:id',
        builder: (_, state) => ManagerDetailScreen(
          managerId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/managers/:id/edit',
        builder: (_, state) {
          final manager = state.extra as dynamic;
          return ManagerFormScreen(manager: manager);
        },
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
        path: AppRoutes.announce,
        builder: (context, state) => const AnnounceFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationListScreen(),
      ),
      GoRoute(
        path: AppRoutes.notificationDetail,
        builder: (context, state) {
          final notif = state.extra as dynamic; // Cast to NotificationModel in screen
          return NotificationDetailScreen(notification: notif);
        },
      ),
      // Module Chat
      GoRoute(
        path: AppRoutes.chatList,
        builder: (context, state) => const ManagerChatListScreen(),
      ),
      GoRoute(
        path: AppRoutes.chatResident,
        builder: (context, state) => const ChatScreen(title: 'Chat với Ban Quản Lý'),
      ),
      GoRoute(
        path: '/manager/chat/:id',
        builder: (context, state) {
          final residentId = int.parse(state.pathParameters['id']!);
          final title = state.extra as String? ?? 'Chat với Cư Dân';
          return ChatScreen(partnerId: residentId, title: title);
        },
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
      // Module 6: Căn hộ (UC29-UC32)
      GoRoute(
        path: AppRoutes.apartmentList,
        builder: (context, state) => const ApartmentListScreen(showBack: true),
      ),
      GoRoute(
        path: AppRoutes.apartmentCreate,
        builder: (context, state) => const ApartmentFormScreen(),
      ),
      GoRoute(
        path: '/manager/apartments/:id',
        builder: (context, state) => ApartmentDetailScreen(
          apartmentId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/manager/apartments/:id/edit',
        builder: (context, state) {
          final apartment = state.extra as Apartment?;
          if (apartment != null) {
            return ApartmentFormScreen(apartment: apartment);
          }
          final detail = ref.read(apartmentDetailProvider).value;
          if (detail != null) {
            final apt = Apartment(
              id: detail.id,
              unitNumber: detail.unitNumber,
              floor: detail.floor,
              status: detail.status,
              areaSize: detail.areaSize,
              baseRent: detail.baseRent,
              ownerId: detail.ownerId,
              ownerName: detail.ownerName,
              ownerPhone: detail.ownerPhone,
              unpaidInvoiceCount: 0,
              unresolvedTicketCount: 0,
            );
            return ApartmentFormScreen(apartment: apt);
          }
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        },
      ),
      GoRoute(
        path: '/manager/apartments/:id/checkin',
        builder: (context, state) => ApartmentCheckinScreen(
          apartmentId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/manager/apartments/:id/checkout',
        builder: (context, state) => ApartmentCheckoutScreen(
          apartmentId: int.parse(state.pathParameters['id']!),
        ),
      ),
      // Module 2: Hợp đồng & Gia hạn lưu trú (UC06-UC09)
      GoRoute(
        path: AppRoutes.myContract,
        builder: (context, state) => const ContractScreen(),
      ),
      // UC07: form gia hạn - nhận MyContract (hợp đồng ACTIVE) qua extra
      GoRoute(
        path: AppRoutes.requestExtension,
        builder: (context, state) =>
            RequestExtensionScreen(myContract: state.extra as MyContract),
      ),
      // Danh sách tất cả hợp đồng (Manager/Landlord) - màn Hợp đồng
      GoRoute(
        path: AppRoutes.contractList,
        builder: (context, state) => const ContractListScreen(),
      ),
      // UC08: danh sách yêu cầu gia hạn (Manager/Landlord)
      GoRoute(
        path: AppRoutes.extensionList,
        builder: (context, state) => const ExtensionListScreen(),
      ),
      // UC09: màn duyệt/từ chối yêu cầu
      GoRoute(
        path: '/manager/extensions/:id',
        builder: (context, state) => ExtensionReviewScreen(
          extensionId: int.parse(state.pathParameters['id']!),
        ),
      ),
      // Module 4: Sự cố & Công việc (UC18-UC23)
      GoRoute(
        path: AppRoutes.ticketCreate,
        builder: (context, state) => const TicketCreateScreen(),
      ),
      GoRoute(
        path: AppRoutes.tickets,
        builder: (context, state) => const TicketListScreen(showBack: true),
      ),
      // Đăng ký sau '/tickets/create' để ':id' không nuốt mất 'create'
      GoRoute(
        path: '/tickets/:id',
        builder: (context, state) => TicketDetailScreen(
          ticketId: int.parse(state.pathParameters['id']!),
        ),
      ),
      // UC21: màn phân công - nhận TicketDetail (PENDING) qua extra
      GoRoute(
        path: '/tickets/:id/assign',
        builder: (context, state) =>
            AssignTaskScreen(ticket: state.extra as TicketDetail),
      ),
      // UC23: chi tiết công việc + cập nhật tiến độ (staff)
      GoRoute(
        path: '/tasks/:id',
        builder: (context, state) => TaskDetailScreen(
          taskId: int.parse(state.pathParameters['id']!),
        ),
      ),
    ],
  );
});
