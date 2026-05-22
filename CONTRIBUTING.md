# Hướng dẫn Đóng góp (Contributing Guidelines)

Cảm ơn bạn đã quan tâm đóng góp cho dự án **Apartment Management**. Vui lòng tuân theo các quy tắc dưới đây để đảm bảo code quality và consistency.

## 📋 Quy tắc Commit Message (Conventional Commits)

Mọi commit phải tuân theo format sau để dễ quản lý version và changelog:

```
<type>(<scope>): <subject>
<blank line>
<body>
<blank line>
<footer>
```

### Các Type Commit chuẩn:

| Type | Ý nghĩa | Ví dụ |
|------|---------|--------|
| **feat** | Thêm tính năng mới | `feat(auth): add login screen` |
| **fix** | Sửa bug | `fix(ui): resolve button alignment issue` |
| **ui** | Chính giao diện | `ui(theme): update color scheme` |
| **refactor** | Tối ưu code không đổi chức năng | `refactor(api): simplify data model` |
| **style** | Format code (whitespace, semicolons) | `style: format code with prettier` |
| **docs** | Tài liệu | `docs: update README installation steps` |
| **test** | Thêm/sửa test | `test(auth): add login validation tests` |
| **chore** | Config/package/build | `chore: update dependencies` |
| **perf** | Tối ưu performance | `perf(list): optimize data loading` |
| **firebase** | Config firebase | `firebase: setup realtime database` |
| **init** | Khởi tạo project | `init: initial project setup` |

### Ví dụ Commit đúng:

```
feat(home): add apartment list view

- Display apartments in a ListView
- Add search functionality
- Add apartment detail navigation

Closes #123
```

## 🎨 Code Style & Naming Conventions

### Dart/Flutter Code Style

1. **Naming Conventions:**
   ```dart
   // Classes: PascalCase
   class ApartmentCard { }
   
   // Functions/Methods: camelCase
   void fetchApartmentList() { }
   
   // Constants: camelCase
   const maxRetries = 3;
   
   // Private members: leading underscore
   String _privateVariable;
   void _privateMethod() { }
   
   // Enum: PascalCase
   enum ApartmentStatus { active, inactive, maintenance }
   ```

2. **File naming:**
   ```
   // Screens: snake_case
   home_screen.dart
   apartment_detail_screen.dart
   
   // Models: snake_case
   apartment_model.dart
   user_model.dart
   
   // Widgets: snake_case
   apartment_card.dart
   custom_button.dart
   ```

3. **Formatting:**
   - Sử dụng `dart format` trước khi commit
   - Dòng tối đa 80 ký tự
   - 2 spaces indent (default Dart)
   - Loại bỏ trailing whitespace

   ```bash
   # Format code
   dart format lib/
   ```

4. **Linting:**
   - Tuân theo rules trong `analysis_options.yaml`
   - Chạy `flutter analyze` để check linting

   ```bash
   flutter analyze
   ```

### Project Structure

```
lib/
├── main.dart
├── screens/           # UI screens
├── widgets/          # Reusable widgets
├── models/           # Data models
├── services/         # API, Firebase services
├── providers/        # State management (Provider, Bloc, etc)
├── utils/            # Utilities, helpers
├── constants/        # App constants
└── config/           # App configuration
```

## ✅ Testing Requirements

### Bắt buộc viết test cho:

1. **Unit Tests** (Business Logic)
   ```dart
   // test/services/apartment_service_test.dart
   void main() {
     test('fetchApartments returns list of apartments', () async {
       // Arrange
       final service = ApartmentService();
       
       // Act
       final apartments = await service.fetchApartments();
       
       // Assert
       expect(apartments, isNotEmpty);
     });
   }
   ```

2. **Widget Tests** (UI Components)
   ```dart
   // test/widgets/apartment_card_test.dart
   void main() {
     testWidgets('ApartmentCard displays apartment info', (WidgetTester tester) async {
       await tester.pumpWidget(MaterialApp(
         home: ApartmentCard(apartment: mockApartment),
       ));
       
       expect(find.text('Apartment Name'), findsOneWidget);
     });
   }
   ```

### Chạy test:

```bash
# Chạy tất cả tests
flutter test

# Chạy test file cụ thể
flutter test test/services/apartment_service_test.dart

# Chạy test với coverage
flutter test --coverage
```

### Coverage Targets:

- **Services** (API, Firebase): ≥ 80%
- **Models** (Data models): ≥ 70%
- **Widgets**: ≥ 60%

## 🌿 Branch Naming Convention (Recommended)

```
feature/add-login-screen
bugfix/fix-apartment-filter
hotfix/critical-crash
docs/update-readme
refactor/simplify-api-service
```

## 🔄 Git Workflow

1. **Tạo branch mới:**
   ```bash
   git checkout -b feature/new-feature
   ```

2. **Commit thường xuyên:**
   ```bash
   git commit -m "feat(feature): description"
   ```

3. **Push và tạo Pull Request:**
   ```bash
   git push origin feature/new-feature
   ```

4. **PR Requirements:**
   - ✅ Tất cả tests phải pass
   - ✅ Code phải tuân theo linting rules
   - ✅ Commit messages phải theo convention
   - ✅ Code review từ 1 thành viên

## 📦 Setup Development Environment

```bash
# Clone repository
git clone <repo-url>

# Install dependencies
flutter pub get

# Run the app
flutter run

# Run tests
flutter test
```

## 🚀 Before Pushing Code

Checklist trước khi commit:

- [ ] `flutter analyze` - không có warnings/errors
- [ ] `dart format lib/` - code formatted
- [ ] `flutter test` - tất cả tests pass
- [ ] Commit message tuân theo convention
- [ ] Không có debug print/log statements
- [ ] Không commit `.env` files hoặc credentials

## 📞 Câu hỏi hoặc Vấn đề?

Tạo issue hoặc liên hệ team lead để thảo luận về quy tắc.

---

**Last Updated:** May 2026
