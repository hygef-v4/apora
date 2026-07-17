import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Hằng số cấu hình API.
///
/// Base URL mặc định trỏ về backend dev qua Android Emulator (10.0.2.2 = localhost máy host).
/// Override khi chạy thiết bị thật / iOS simulator:
///   Thêm file .env vào thư mục mobile/
class ApiConstants {
  ApiConstants._();

  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api',
  );

  // Auth (UC01-UC03)
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // User (UC04-UC05)
  static const String profile = '/users/profile';
  static const String changePassword = '/users/change-password';

  // Module 2 - Hợp đồng & Gia hạn lưu trú (UC06-UC09)
  static const String myContract = '/contracts/my'; // GET hợp đồng của tôi (UC06)
  static const String stayExtensions = '/stay-extensions'; // GET list (UC08), POST gửi yêu cầu (UC07)
  static String stayExtensionDetail(int id) => '/stay-extensions/$id'; // GET chi tiết (UC09)
  static String stayExtensionReview(int id) => '/stay-extensions/$id/review'; // PUT duyệt/từ chối (UC09)

  // Module 4 - Sự cố & Công việc (UC18-UC23)
  static const String tickets = '/tickets'; // GET danh sách (UC18), POST tạo (UC19)
  static String ticketDetail(int id) => '/tickets/$id'; // GET chi tiết (UC20)
  static String ticketStatus(int id) => '/tickets/$id/status'; // PUT đổi trạng thái (UC20)
  static String ticketAssign(int id) => '/tickets/$id/assign'; // POST phân công (UC21)
  static const String staffWorkload = '/staff/workload'; // GET bảng tải việc nhân viên (UC21)
  static const String tasks = '/tasks'; // GET công việc của tôi (UC22)
  static String taskDetail(int id) => '/tasks/$id'; // GET chi tiết công việc (UC23)
  static String taskProgress(int id) => '/tasks/$id/progress'; // PUT cập nhật tiến độ (UC23)
}

/// Key lưu trữ trong flutter_secure_storage (KHÔNG dùng SharedPreferences).
class StorageKeys {
  StorageKeys._();

  static const String jwtToken = 'jwt_token';
  static const String userJson = 'user_json';
  static const String mustChangePassword = 'must_change_password';
}
