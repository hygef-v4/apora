/// Chuỗi hiển thị tiếng Việt dùng chung toàn app.
/// Message code (MSG01, MSG02...) theo SRS.
class AppStrings {
  AppStrings._();

  static const String appName = 'APORA';

  // Validate (MSG01)
  static const String msgPhoneRequired = 'Vui lòng nhập Số điện thoại.';
  static const String msgPasswordRequired = 'Vui lòng nhập Mật khẩu.';
  static const String msgFieldRequired = 'Trường bắt buộc không được để trống.';

  // Login (MSG02)
  static const String msgLoginFailed =
      'Số điện thoại hoặc mật khẩu không đúng. Vui lòng kiểm tra lại.';

  // Lỗi chung
  static const String msgNetworkError =
      'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng và thử lại.';
  static const String msgUnknownError = 'Đã có lỗi xảy ra. Vui lòng thử lại sau.';
  static const String msgSessionExpired =
      'Phiên đăng nhập đã hết hiệu lực. Vui lòng đăng nhập lại.';

  // OTP / mật khẩu
  static const String msgOtpSent = 'Mã OTP đã được gửi tới số điện thoại của bạn.';
  static const String msgOtpInvalid =
      'Mã OTP không hợp lệ hoặc đã hết hạn. Vui lòng yêu cầu mã mới.';
  static const String msgPasswordMismatch = 'Mật khẩu xác nhận không khớp.';
  static const String msgSamePassword =
      'Mật khẩu mới không được trùng mật khẩu hiện tại.';
  static const String msgChangePasswordFirstLogin =
      'Bạn đang dùng mật khẩu mặc định. Vui lòng đổi mật khẩu để tiếp tục.';

  // UC05/UC39 - AT3: text đã lưu nhưng avatar upload thất bại
  static const String msgAvatarUploadFailed =
      'Đã lưu thông tin, nhưng ảnh đại diện chưa tải lên được. Vui lòng thử lại sau.';

  // Module 8: Quản lý nhân viên (UC36-UC40)
  static const String msgStaffEmpty = 'Chưa có nhân viên nào.';
  static const String msgStaffNoMatch = 'Không tìm thấy nhân viên phù hợp.';
  static const String msgStaffLoadFailed =
      'Không tải được danh sách nhân viên. Vui lòng thử lại.';
  static const String msgStaffHasOpenTasks =
      'Nhân viên còn công việc chưa xử lý. Vui lòng phân công lại tất cả công việc trước khi vô hiệu hóa.';
  static const String msgStaffDeactivateConfirm =
      'Bạn có chắc muốn vô hiệu hóa tài khoản nhân viên này? Nhân viên sẽ bị đăng xuất khỏi mọi thiết bị và không thể đăng nhập lại.';
  static const String msgUnsavedChanges =
      'Dữ liệu chưa lưu sẽ bị mất. Bạn có chắc muốn thoát?';
  static const String msgRoleChangeWarning =
      'Nhân viên này còn công việc đang xử lý. Đổi vai trò có thể khiến công việc cần được phân công lại. Tiếp tục?';

  // Module 9: Quản lý Manager (UC41-UC42)
  static const String msgManagerEmpty = 'Chưa có tài khoản quản lý nào.';
  static const String msgManagerNoMatch = 'Không tìm thấy quản lý phù hợp.';
  static const String msgManagerLoadFailed =
      'Không tải được danh sách quản lý. Vui lòng thử lại.';
}
