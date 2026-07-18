/// Validator dùng chung cho form (client-side, khớp rule backend).
class Validators {
  Validators._();

  /// BR-09: mật khẩu >= 8 ký tự, >= 1 chữ hoa, >= 1 chữ số.
  /// Validate ngay trên client để người dùng không phải chờ server trả lỗi.
  /// @returns null nếu hợp lệ, ngược lại là message lỗi tiếng Việt.
  static String? passwordComplexity(String? password) {
    if (password == null || password.isEmpty) {
      return 'Trường bắt buộc không được để trống.';
    }
    if (password.length < 8) {
      return 'Mật khẩu phải có ít nhất 8 ký tự.';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Mật khẩu phải chứa ít nhất 1 chữ cái viết hoa.';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Mật khẩu phải chứa ít nhất 1 chữ số.';
    }
    return null;
  }
}
