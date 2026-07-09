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
