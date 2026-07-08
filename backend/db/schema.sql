-- ============================================
-- APORA - Database Schema (Module 1: Auth & Profile, UC01-UC05)
-- Chạy trên Supabase SQL Editor hoặc psql.
-- Các bảng của module sau (contracts, invoices, ...) sẽ bổ sung dần.
-- ============================================

-- Bảng USERS (theo SRS mục Data Dictionary "User")
-- Mở rộng so với SRS (có ghi trong CLAUDE.md):
--   + must_change_password: phục vụ BR-01 (đổi mật khẩu ở lần đăng nhập đầu)
--   + token_version: phục vụ BR-07 (vô hiệu hóa mọi JWT khi reset mật khẩu)
CREATE TABLE IF NOT EXISTS users (
  id                    SERIAL PRIMARY KEY,
  phone_number          VARCHAR(15) NOT NULL UNIQUE,          -- BR-02: username duy nhất toàn hệ thống
  password_hash         TEXT        NOT NULL,                 -- BR-03: bcrypt
  full_name             VARCHAR(100) NOT NULL,
  avatar_url            TEXT,
  roles                 TEXT[]      NOT NULL,                 -- LANDLORD | MANAGER | RESIDENT | SECURITY_GUARD | JANITOR | TECHNICIAN
  status                VARCHAR(10) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE')),
  must_change_password  BOOLEAN     NOT NULL DEFAULT TRUE,    -- BR-01
  token_version         INTEGER     NOT NULL DEFAULT 0,       -- BR-07
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Bảng DEVICE_TOKENS (theo SRS "Device Token") - BR-44
-- Lưu FCM token khi login, revoke khi logout.
CREATE TABLE IF NOT EXISTS device_tokens (
  id          SERIAL PRIMARY KEY,
  user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token       TEXT    NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  revoked_at  TIMESTAMPTZ,
  UNIQUE (user_id, token)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user_active
  ON device_tokens (user_id) WHERE revoked_at IS NULL;

-- Bảng PASSWORD_RESET_OTPS (theo SRS "Password Reset OTP")
-- BR-08: OTP hết hạn sau 5 phút. attempt_count tối đa 3 lần sai.
CREATE TABLE IF NOT EXISTS password_reset_otps (
  id             SERIAL PRIMARY KEY,
  phone_number   VARCHAR(15) NOT NULL,
  otp_code       VARCHAR(6)  NOT NULL,
  expired_at     TIMESTAMPTZ NOT NULL,
  is_used        BOOLEAN     NOT NULL DEFAULT FALSE,
  attempt_count  INTEGER     NOT NULL DEFAULT 0,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_password_reset_otps_phone
  ON password_reset_otps (phone_number, is_used, expired_at);

-- ============================================
-- Module 4 & 6 & 8: Apartments / Repair Tickets / Tasks
-- (Tạo trước theo SD để Module 8 query workload BR-50;
--  logic Module 4/6 sẽ triển khai sau, không cần đổi schema.)
-- ============================================

-- Bảng APARTMENTS (theo SRS "Apartment")
CREATE TABLE IF NOT EXISTS apartments (
  id           SERIAL PRIMARY KEY,
  unit_number  VARCHAR(20)  NOT NULL UNIQUE,
  floor        VARCHAR(10)  NOT NULL,
  owner_id     INTEGER REFERENCES users(id),
  status       VARCHAR(10)  NOT NULL DEFAULT 'EMPTY' CHECK (status IN ('EMPTY', 'OCCUPIED', 'INACTIVE'))
);

-- Bảng REPAIR_TICKETS (theo SD Module 4 - RepairTicket entity)
-- Trạng thái theo bộ đã chốt (Software Design 3.4, xem CLAUDE.md)
CREATE TABLE IF NOT EXISTS repair_tickets (
  id             SERIAL PRIMARY KEY,
  apartment_id   INTEGER NOT NULL REFERENCES apartments(id),
  resident_id    INTEGER NOT NULL REFERENCES users(id),
  category       VARCHAR(50)  NOT NULL,
  description    VARCHAR(500) NOT NULL,       -- BR-36: 10-500 ký tự (validate ở service)
  before_images  TEXT[]       NOT NULL DEFAULT '{}',  -- BR-37: tối đa 3 ảnh
  status         VARCHAR(15)  NOT NULL DEFAULT 'PENDING'
                 CHECK (status IN ('PENDING', 'ASSIGNED', 'PROCESSING', 'RESOLVED', 'CANCELLED')),
  internal_notes TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Bảng TASKS (theo SD Module 4 - Task entity)
-- Công việc giao cho Staff từ một repair ticket.
CREATE TABLE IF NOT EXISTS tasks (
  id                 SERIAL PRIMARY KEY,
  ticket_id          INTEGER NOT NULL REFERENCES repair_tickets(id),
  assigned_to        INTEGER NOT NULL REFERENCES users(id),
  assigned_by        INTEGER NOT NULL REFERENCES users(id),
  title              VARCHAR(100) NOT NULL,
  description        TEXT,
  progress_notes     TEXT,
  completion_images  TEXT[] NOT NULL DEFAULT '{}',    -- BR-43: >=1 ảnh khi COMPLETED
  status             VARCHAR(15) NOT NULL DEFAULT 'ASSIGNED'
                     CHECK (status IN ('ASSIGNED', 'IN_PROGRESS', 'COMPLETED')),
  assigned_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at       TIMESTAMPTZ
);

-- Query workload (BR-41, BR-50): đếm task chưa xong theo staff
CREATE INDEX IF NOT EXISTS idx_tasks_assigned_open
  ON tasks (assigned_to) WHERE status <> 'COMPLETED';

-- ============================================
-- Module 8/9: Audit log (UC39/UC40 BR-04)
-- Mở rộng có chủ đích so với 15 bảng SRS (yêu cầu "dedicated audit log table").
-- ============================================

CREATE TABLE IF NOT EXISTS audit_logs (
  id              SERIAL PRIMARY KEY,
  actor_id        INTEGER NOT NULL REFERENCES users(id),  -- Manager/Landlord thao tác
  target_user_id  INTEGER REFERENCES users(id),
  action          VARCHAR(50) NOT NULL,                    -- vd: STAFF_CREATE, STAFF_UPDATE, STAFF_DEACTIVATE
  old_value       JSONB,
  new_value       JSONB,
  reason          VARCHAR(250),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_target ON audit_logs (target_user_id, created_at DESC);
