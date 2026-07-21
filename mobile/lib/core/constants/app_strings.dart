/// Chuỗi hiển thị dùng chung toàn app (tiếng Anh, khớp message của backend).
/// Message code (MSG01, MSG02...) theo SRS.
class AppStrings {
  AppStrings._();

  static const String appName = 'APORA';

  // Validate (MSG01)
  static const String msgPhoneRequired = 'Please enter a phone number.';
  static const String msgPasswordRequired = 'Please enter a password.';
  static const String msgFieldRequired = 'This field is required.';

  // Login (MSG02)
  static const String msgLoginFailed =
      'Incorrect phone number or password. Please check and try again.';

  // UC02: xác nhận đăng xuất (FID-02 - Confirmation Dialog bắt buộc)
  static const String msgLogoutConfirm = 'Are you sure you want to log out?';

  // UC05 - AT4: bấm Lưu khi không sửa gì
  static const String msgNoChanges = 'There are no changes to save.';

  static const String msgPhoneInvalid =
      'Invalid phone number. Enter 10 digits starting with 0.';

  // Lỗi chung
  static const String msgNetworkError =
      'Cannot reach the server. Please check your connection and try again.';
  static const String msgUnknownError =
      'Something went wrong. Please try again later.';
  static const String msgSessionExpired =
      'Your session has expired. Please log in again.';

  // OTP / mật khẩu
  static const String msgOtpSent = 'An OTP code has been sent to your phone.';
  static const String msgOtpInvalid =
      'The OTP code is invalid or has expired. Please request a new one.';
  static const String msgPasswordMismatch = 'The confirmation password does not match.';
  static const String msgSamePassword =
      'The new password must be different from the current one.';
  static const String msgChangePasswordFirstLogin =
      'You are using the default password. Please change it to continue.';

  // UC05/UC39 - AT3: text đã lưu nhưng avatar upload thất bại
  static const String msgAvatarUploadFailed =
      'Details were saved, but the avatar could not be uploaded. Please try again later.';

  // Module 8: Quản lý nhân viên (UC36-UC40)
  static const String msgStaffEmpty = 'No staff accounts yet.';
  static const String msgStaffNoMatch = 'No staff match your search.';
  static const String msgStaffLoadFailed =
      'Could not load the staff list. Please try again.';
  static const String msgStaffHasOpenTasks =
      'This staff member still has unresolved tickets. Please reassign all open tickets before deactivation.';
  static const String msgStaffDeactivateConfirm =
      'This staff member will no longer be able to log in or receive repair '
      'tasks, and will be signed out of every device.';
  static const String msgUnsavedChanges =
      'Unsaved changes will be lost. Do you want to leave?';
  static const String msgRoleChangeWarning =
      'This staff member still has open tickets. Changing their role may require those tickets to be reassigned. Continue?';

  // Module 9: Quản lý Manager (UC41-UC42)
  static const String msgManagerEmpty = 'Chưa có tài khoản quản lý nào.';
  static const String msgManagerNoMatch = 'Không tìm thấy quản lý phù hợp.';
  static const String msgManagerLoadFailed =
      'Không tải được danh sách quản lý. Vui lòng thử lại.';
}
