import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lỗi luồng OTP với message tiếng Việt sẵn sàng hiển thị (SnackBar).
class OtpException implements Exception {
  const OtpException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// UC03: Bọc Firebase Phone Auth cho luồng quên mật khẩu (BR-08).
/// Firebase đảm nhiệm gửi SMS, hết hạn mã và giới hạn nhập sai;
/// app chỉ cần verificationId + mã người dùng nhập để lấy Firebase ID token,
/// backend verify token đó rồi mới đổi mật khẩu.
class PhoneOtpService {
  String? _verificationId;

  /// ID token có sẵn khi Android auto-verify SMS (verificationCompleted) -
  /// người dùng không cần gõ mã.
  String? _autoIdToken;

  /// SĐT VN 0xxxxxxxxx -> E.164 +84xxxxxxxxx (định dạng Firebase yêu cầu).
  static String toE164Vn(String phone) {
    final trimmed = phone.trim();
    if (trimmed.startsWith('+')) return trimmed;
    if (trimmed.startsWith('0')) return '+84${trimmed.substring(1)}';
    return '+84$trimmed';
  }

  /// Bước 1 + Resend: nhờ Firebase gửi SMS OTP tới [phone] (dạng 0xxxxxxxxx).
  /// Future hoàn thành khi mã đã được gửi (codeSent) hoặc Android auto-verify.
  Future<void> sendOtp(String phone) async {
    _autoIdToken = null;
    final completer = Completer<void>();

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: toE164Vn(phone),
      timeout: const Duration(seconds: 60),
      // Android auto-retrieval: SMS được đọc tự động -> đăng nhập luôn,
      // cache ID token để bước xác nhận không cần mã.
      verificationCompleted: (credential) async {
        try {
          final result =
              await FirebaseAuth.instance.signInWithCredential(credential);
          _autoIdToken = await result.user?.getIdToken();
        } catch (_) {
          // Auto-verify lỗi -> người dùng vẫn nhập mã tay được
        }
        if (!completer.isCompleted) completer.complete();
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) {
          completer.completeError(OtpException(_mapFirebaseError(e)));
        }
      },
      codeSent: (verificationId, _) {
        _verificationId = verificationId;
        if (!completer.isCompleted) completer.complete();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );

    return completer.future;
  }

  /// Bước 2: xác nhận [smsCode] với Firebase, trả về Firebase ID token
  /// để backend verify. Ném [OtpException] nếu mã sai/hết hạn.
  Future<String> confirmAndGetIdToken(String smsCode) async {
    // Android đã auto-verify -> dùng luôn token cache
    if (_autoIdToken != null) return _autoIdToken!;

    // Retry sau khi backend từ chối (vd mật khẩu trùng): phiên Firebase còn
    // đăng nhập -> lấy lại token, không bắt người dùng xin OTP mới.
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final token = await currentUser.getIdToken();
      if (token != null) return token;
    }

    final verificationId = _verificationId;
    if (verificationId == null) {
      throw const OtpException(
        'Chưa gửi được mã OTP. Vui lòng bấm "Gửi lại OTP" và thử lại.',
      );
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      final result =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final idToken = await result.user?.getIdToken();
      if (idToken == null) {
        throw const OtpException(
          'Không xác thực được mã OTP. Vui lòng thử lại.',
        );
      }
      return idToken;
    } on FirebaseAuthException catch (e) {
      throw OtpException(_mapFirebaseError(e));
    }
  }

  /// Dọn phiên Firebase tạm sau khi đổi mật khẩu xong (phiên chỉ dùng để
  /// chứng minh sở hữu SĐT, không phải phiên đăng nhập của app).
  Future<void> clearSession() async {
    _verificationId = null;
    _autoIdToken = null;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Không chặn luồng chính nếu signOut lỗi
    }
  }

  /// Map mã lỗi Firebase Auth -> message tiếng Việt thân thiện.
  static String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'Mã OTP không đúng. Vui lòng kiểm tra lại.';
      case 'session-expired':
      case 'code-expired':
        return 'Mã OTP đã hết hạn. Vui lòng bấm "Gửi lại OTP".';
      case 'invalid-phone-number':
        return 'Số điện thoại không hợp lệ. Vui lòng nhập 10 chữ số bắt đầu bằng 0.';
      case 'too-many-requests':
        return 'Bạn đã yêu cầu OTP quá nhiều lần. Vui lòng thử lại sau ít phút.';
      case 'network-request-failed':
        return 'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng và thử lại.';
      default:
        return 'Không gửi/xác thực được mã OTP. Vui lòng thử lại sau. (${e.code})';
    }
  }
}

final phoneOtpServiceProvider = Provider<PhoneOtpService>((_) => PhoneOtpService());
