# QUY CHUẨN VIẾT TEST (APORA MOBILE)

Đây là tài liệu bắt buộc tuân thủ khi viết Unit Test & Widget Test cho các module trong dự án Apora Mobile. Mục tiêu tối thượng là đảm bảo **100% Coverage** cho mọi Use Case và tuân thủ tuyệt đối các Business Rules đã định nghĩa.

## 1. Yêu Cầu Bắt Buộc Về Coverage & Business Rules
- **100% Coverage:** File test phải bao phủ (cover) toàn bộ các nhánh logic (if/else), các trạng thái (Loading, Success, Error), và giao diện hiển thị của toàn bộ một Use Case. Mọi phương thức, mọi state đều phải được quét qua.
- **Tuân thủ Business Rules:** Bắt buộc viết test để mô phỏng và kiểm chứng TẤT CẢ các Business Rules (BRs) và Alternative Flows (ATs) có trong đặc tả yêu cầu (SRS) của Use Case đó. Nếu Business Rule yêu cầu bắt lỗi độ dài, định dạng, phân quyền, hoặc kích thước file... thì phải có test case tương ứng.
- **Check lại Document (SRS/SDD):** Trước khi viết test, bắt buộc phải kiểm tra lại tài liệu đặc tả (SRS/SDD) để tìm và liệt kê đầy đủ các luồng và rules.
- Mọi Use Case phải được test 100% logic bao gồm cả Happy Path (Luồng chính) và **Alternative Flows (Luồng phụ)**.
- Các **Business Rules (Quy tắc nghiệp vụ)** (nén ảnh, giao diện theo loại dữ liệu, phân quyền RBAC, v.v.) phải được test đầy đủ theo sát yêu cầu trong tài liệu.
- Đảm bảo kiểm tra các luồng như lỗi kết nối mạng, báo lỗi từ API, danh sách rỗng (Empty State), và các hiển thị theo trạng thái.


## 2. Yêu Cầu Chung
- **Bắt buộc tách file theo Use Case:** Không gom chung các Use Case vào một file test. Mỗi Use Case phải có một file test độc lập.
- **Tên file:** Phải đặt theo tên của Use Case, tuyệt đối **không được** thêm tiền tố `uc_`.
  - ✅ Đúng: `announce_notification_test.dart`, `view_notifications_test.dart`
  - ❌ Sai: `uc24_announce_notification_test.dart`
- **Khởi tạo môi trường:**
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  setUpAll(() async {
    // Bắt buộc load .env (hoặc .env.test) để tránh lỗi DotEnv not initialized
    await dotenv.load(fileName: ".env");
  });
  // ...
}
```
- **Tách Biệt Tầng Test**:
   Mỗi màn hình / Use Case phải được tách thành 3 layer test rõ ràng bằng `group`:
   - `1. UI & Widget Tests`
   - `2. Domain & State Management`
   - `3. Repository Layer`

## 3. Tiêu Chuẩn Phủ Sóng Cho Từng Layer
### 3.1. Tầng UI & Widget Tests (Ưu Tiên Số 1)
- **Render:** Phải test giao diện hiển thị đầy đủ các thành phần tĩnh (Text, Input, Button...).
- **Validation (Business Rules):** Phải viết test để mô phỏng các Alternative Flows (VD: bỏ trống input, input sai định dạng, vượt quá ký tự cho phép) và verify các text báo lỗi hiện lên đúng.
- **Loading State:** Phải test việc nhấn nút submit, giao diện hiện `CircularProgressIndicator` (hoặc shimmer) và vô hiệu hóa các nút bấm, ngăn người dùng submit nhiều lần.
- **Success & Error UI:** Bắt buộc test hiển thị `SnackBar` thông báo lỗi hoặc thành công.
- **Navigation:** Nếu luồng thành công hoặc thất bại yêu cầu điều hướng (`context.pop()`, `context.go()`), phải verify là lệnh điều hướng đã được gọi.

### 3.2. Tầng Domain & State Management
- **Initial State:** Phải test giá trị mặc định của Notifier/State khi vừa khởi tạo.
- **Happy Path:** Gọi phương thức trong Notifier (ví dụ submit) và assert các state chuyển đổi đúng (`isLoading = true` -> `isSuccess = true`).
- **Error Path:** Bắt buộc test trường hợp API trả về lỗi (Exception) và kiểm tra state `error` chứa đúng message lỗi phân quyền hoặc lỗi hệ thống.

### 3.3. Tầng Repository
- **API Calling:** Phải dùng Mock (như `MockDio` hoặc mock http client) để verify rằng repository gọi đúng method (`GET`, `POST`, `PUT`, `DELETE`), đúng `path`, và truyền đủ `data`/`queryParameters` / `FormData` y hệt như tài liệu API và Business Rule quy định.
