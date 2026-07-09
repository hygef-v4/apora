/// Hằng số cấu hình API.
///
/// Base URL mặc định trỏ về backend dev qua Android Emulator (10.0.2.2 = localhost máy host).
/// Override khi chạy thiết bị thật / iOS simulator:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000/api
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
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

  // Module 4 - Sự cố & Công việc (UC18-UC23)
  static const String tickets = '/tickets'; // GET danh sách (UC18), POST tạo (UC19)
  static String ticketDetail(int id) => '/tickets/$id'; // GET chi tiết (UC20)
  static String ticketStatus(int id) => '/tickets/$id/status'; // PUT đổi trạng thái (UC20)
  static String ticketAssign(int id) => '/tickets/$id/assign'; // POST phân công (UC21)
  static const String staffWorkload = '/staff/workload'; // GET bảng tải việc nhân viên (UC21)
  static const String tasks = '/tasks'; // GET công việc của tôi (UC22)
  static String taskProgress(int id) => '/tasks/$id/progress'; // PUT cập nhật tiến độ (UC23)
}

/// Key lưu trữ trong flutter_secure_storage (KHÔNG dùng SharedPreferences).
class StorageKeys {
  StorageKeys._();

  static const String jwtToken = 'jwt_token';
  static const String userJson = 'user_json';
  static const String mustChangePassword = 'must_change_password';
}
