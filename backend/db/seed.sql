-- ============================================
-- APORA - Seed dữ liệu dev (Module 1)
-- Mật khẩu mặc định cho cả 3 tài khoản: Apora@123
-- Hash bằng pgcrypto (bcrypt $2a$ - node bcrypt verify bình thường).
-- KHÔNG chạy seed này trên môi trường production.
-- ============================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

INSERT INTO users (phone_number, password_hash, full_name, roles, must_change_password)
VALUES
  ('0900000001', crypt('Apora@123', gen_salt('bf', 10)), 'Chủ Tòa Nhà',      ARRAY['LANDLORD'],  TRUE),
  ('0900000002', crypt('Apora@123', gen_salt('bf', 10)), 'Ban Quản Lý',       ARRAY['MANAGER'],   TRUE),
  ('0900000003', crypt('Apora@123', gen_salt('bf', 10)), 'Nguyễn Văn Cư Dân', ARRAY['RESIDENT'],  TRUE),
  ('0900000004', crypt('Apora@123', gen_salt('bf', 10)), 'Trần Văn Kỹ Thuật', ARRAY['TECHNICIAN'],     TRUE),
  ('0900000005', crypt('Apora@123', gen_salt('bf', 10)), 'Lê Văn Bảo Vệ',     ARRAY['SECURITY_GUARD'], TRUE)
ON CONFLICT (phone_number) DO NOTHING;

-- Seed đơn giá mặc định ban đầu nếu bảng pricing_settings đang trống
INSERT INTO pricing_settings (electricity_rate, water_rate, mgmt_fee, created_by)
SELECT 2000.00, 2166.00, 150000.00, 2
WHERE NOT EXISTS (SELECT 1 FROM pricing_settings);

-- Seed căn hộ mẫu
INSERT INTO apartments (unit_number, floor, owner_id, status)
VALUES 
  ('101', '1', (SELECT id FROM users WHERE phone_number = '0900000003'), 'OCCUPIED'),
  ('102', '1', NULL, 'EMPTY')
ON CONFLICT (unit_number) DO NOTHING;

-- Seed hợp đồng thuê hoạt động mẫu cho cư dân
INSERT INTO contracts (apartment_id, resident_id, start_date, end_date, base_rent_snapshot, status)
SELECT 
  (SELECT id FROM apartments WHERE unit_number = '101'),
  (SELECT id FROM users WHERE phone_number = '0900000003'),
  '2026-01-01',
  '2027-01-01',
  10000.00,
  'ACTIVE'
WHERE NOT EXISTS (
  SELECT 1 FROM contracts c
  JOIN apartments a ON c.apartment_id = a.id
  WHERE a.unit_number = '101'
);

