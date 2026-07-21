import '../constants/app_strings.dart';

/// Validator dùng chung cho form (client-side, khớp rule backend).
class Validators {
  Validators._();

  /// BR-02: SĐT là username - đúng định dạng di động VN (10 chữ số, bắt đầu
  /// bằng 0), khớp validatePhoneNumber phía backend.
  /// @returns null nếu hợp lệ, ngược lại là message lỗi (tiếng Anh, khớp backend).
  static String? vnPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      return AppStrings.msgPhoneRequired;
    }
    if (!RegExp(r'^0\d{9}$').hasMatch(phone.trim())) {
      return AppStrings.msgPhoneInvalid;
    }
    return null;
  }

  /// BR-09: mật khẩu >= 8 ký tự, >= 1 chữ hoa, >= 1 chữ số.
  /// Validate ngay trên client để người dùng không phải chờ server trả lỗi.
  /// @returns null nếu hợp lệ, ngược lại là message lỗi (tiếng Anh, khớp backend).
  static String? passwordComplexity(String? password) {
    if (password == null || password.isEmpty) {
      return AppStrings.msgFieldRequired;
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least 1 uppercase letter.';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least 1 digit.';
    }
    return null;
  }
}
