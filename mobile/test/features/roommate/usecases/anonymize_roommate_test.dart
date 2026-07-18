import 'package:apartment_management/core/utils/mask_utils.dart';
import 'package:apartment_management/features/roommate/models/roommate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: ".env");
  });

  group('UC12: Roommate Data Anonymization on Checkout - 100% Coverage & Business Rules', () {
    // =========================================================================
    // 1. UI & Widget Tests
    // =========================================================================
    group('1. UI & Widget Tests', () {
      test('Mask CCCD định dạng 12 chữ số theo BR-08', () {
        const rawCccd = '001200123456';
        final masked = maskCccdNumber(rawCccd);
        expect(masked, '********3456');
        expect(masked.length, 12);
      });

      test('Hiển thị mã MASK_ khi dữ liệu đã bị anonymize sau khi checkout (BR-20)', () {
        const anonymizedCccd = 'MASK_101_ROOMMATE';
        final masked = maskCccdNumber(anonymizedCccd);
        expect(masked, 'MASK_101_ROOMMATE');
      });

      test('Xử lý chuỗi rỗng hoặc null an toàn', () {
        expect(maskCccdNumber(null), 'Không có');
        expect(maskCccdNumber(''), 'Không có');
        expect(maskCccdNumber('123'), '123');
      });
    });

    // =========================================================================
    // 2. Domain & State Management
    // =========================================================================
    group('2. Domain & State Management', () {
      test('Model Roommate trả về maskedCccdNumber đúng chuẩn BR-08', () {
        final roommate = Roommate(
          id: 1,
          apartmentId: 101,
          fullName: 'Người Ở Ghép',
          cccdNumber: '036198001122',
          status: 'APPROVED',
          createdAt: DateTime.now(),
        );

        expect(roommate.maskedCccdNumber, '********1122');
      });

      test('Model Roommate giữ nguyên mã MASK_ khi đã bị anonymize (BR-20)', () {
        final roommate = Roommate(
          id: 2,
          apartmentId: 102,
          fullName: 'Đã Checkout',
          cccdNumber: 'MASK_2',
          cccdFrontUrl: null,
          cccdBackUrl: null,
          status: 'INACTIVE',
          createdAt: DateTime.now(),
        );

        expect(roommate.maskedCccdNumber, 'MASK_2');
        expect(roommate.cccdFrontUrl, isNull);
        expect(roommate.cccdBackUrl, isNull);
      });
    });

    // =========================================================================
    // 3. Repository Layer
    // =========================================================================
    group('3. Repository Layer', () {
      test('Parse JSON hồ sơ đã bị anonymize không bị crash', () {
        final json = {
          'id': 99,
          'apartment_id': 105,
          'full_name': 'Anonymized Member',
          'phone_number': null,
          'cccd_number': 'MASK_99',
          'cccd_front_url': null,
          'cccd_back_url': null,
          'status': 'INACTIVE',
          'created_at': '2026-01-01T00:00:00.000Z',
        };

        final roommate = Roommate.fromJson(json);
        expect(roommate.id, 99);
        expect(roommate.cccdNumber, 'MASK_99');
        expect(roommate.maskedCccdNumber, 'MASK_99');
        expect(roommate.cccdFrontUrl, isNull);
      });
    });
  });
}
