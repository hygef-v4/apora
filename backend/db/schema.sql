-- ============================================
-- APORA - Database Schema (All 9 Modules)
-- ============================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. USERS (Authentication & Profile Management)
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

-- 2. DEVICE_TOKENS (FCM Push Notifications) - BR-44
CREATE TABLE IF NOT EXISTS device_tokens (
  id            SERIAL PRIMARY KEY,
  user_id       INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token         TEXT    NOT NULL,
  device_type   VARCHAR(10) CHECK (device_type IN ('ANDROID', 'IOS', 'WEB')),
  device_name   VARCHAR(100),
  status        VARCHAR(10) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'INACTIVE', 'REVOKED')),
  last_used_at  TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  revoked_at    TIMESTAMPTZ,
  UNIQUE (user_id, token)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user_active
  ON device_tokens (user_id) WHERE revoked_at IS NULL AND status = 'ACTIVE';

-- 3. PASSWORD_RESET_OTPS (Password Recovery) - BR-08
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

-- 4. APARTMENTS (Apartment Management)
CREATE TABLE IF NOT EXISTS apartments (
  id           SERIAL PRIMARY KEY,
  unit_number  VARCHAR(20)  NOT NULL UNIQUE,
  floor        VARCHAR(10)  NOT NULL,
  owner_id     INTEGER REFERENCES users(id),
  status       VARCHAR(10)  NOT NULL DEFAULT 'EMPTY' CHECK (status IN ('EMPTY', 'OCCUPIED', 'INACTIVE'))
);

-- 5. CONTRACTS (Tenancy Management)
CREATE TABLE IF NOT EXISTS contracts (
  id                  SERIAL PRIMARY KEY,
  apartment_id        INTEGER NOT NULL REFERENCES apartments(id),
  resident_id         INTEGER NOT NULL REFERENCES users(id),
  start_date          DATE NOT NULL,
  end_date            DATE NOT NULL,
  base_rent_snapshot  NUMERIC(12, 2) NOT NULL,
  status              VARCHAR(10) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'EXPIRED')),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. INVOICES (Billing Management) - BR-27
CREATE TABLE IF NOT EXISTS invoices (
  id                      SERIAL PRIMARY KEY,
  contract_id             INTEGER NOT NULL REFERENCES contracts(id),
  apartment_id            INTEGER NOT NULL REFERENCES apartments(id), -- Bổ sung để phục vụ BR-27 unique constraint
  month_year              VARCHAR(7)  NOT NULL, -- format: MM/YYYY
  prev_electricity_index  DOUBLE PRECISION NOT NULL,
  curr_electricity_index  DOUBLE PRECISION NOT NULL,
  electricity_consumption DOUBLE PRECISION NOT NULL,
  prev_water_index        DOUBLE PRECISION NOT NULL,
  curr_water_index        DOUBLE PRECISION NOT NULL,
  water_consumption       DOUBLE PRECISION NOT NULL,
  room_rent_snapshot      NUMERIC(12, 2) NOT NULL,
  mgmt_fee_snapshot       NUMERIC(12, 2) NOT NULL,
  extra_fee               NUMERIC(12, 2) NOT NULL DEFAULT 0 CHECK (extra_fee >= 0),
  extra_fee_description   TEXT,
  total_amount            NUMERIC(12, 2) NOT NULL,
  status                  VARCHAR(10) NOT NULL DEFAULT 'UNPAID' CHECK (status IN ('UNPAID', 'PAID')),
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (apartment_id, month_year) -- BR-27: Không tạo trùng hóa đơn tháng của cùng căn hộ
);

-- 7. ROOMMATES (Tenancy Management)
CREATE TABLE IF NOT EXISTS roommates (
  id              SERIAL PRIMARY KEY,
  apartment_id    INTEGER NOT NULL REFERENCES apartments(id),
  full_name       VARCHAR(100) NOT NULL,
  phone_number    VARCHAR(15),
  cccd_number     VARCHAR(15) NOT NULL UNIQUE,
  cccd_front_url  TEXT,
  cccd_back_url   TEXT,
  status          VARCHAR(15) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. REPAIR_TICKETS (Incident Management) - BR-36, BR-37, BR-38
CREATE TABLE IF NOT EXISTS repair_tickets (
  id             SERIAL PRIMARY KEY,
  apartment_id   INTEGER NOT NULL REFERENCES apartments(id),
  resident_id    INTEGER NOT NULL REFERENCES users(id),
  category       VARCHAR(50)  NOT NULL,
  description    VARCHAR(500) NOT NULL,
  before_images  TEXT[]       NOT NULL DEFAULT '{}',
  status         VARCHAR(15)  NOT NULL DEFAULT 'PENDING'
                 CHECK (status IN ('PENDING', 'ASSIGNED', 'PROCESSING', 'RESOLVED', 'CANCELLED')),
  internal_notes TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. TASKS (Incident Management) - BR-43, BR-50
CREATE TABLE IF NOT EXISTS tasks (
  id                 SERIAL PRIMARY KEY,
  ticket_id          INTEGER NOT NULL REFERENCES repair_tickets(id),
  assigned_to        INTEGER NOT NULL REFERENCES users(id),
  assigned_by        INTEGER NOT NULL REFERENCES users(id),
  title              VARCHAR(100) NOT NULL,
  description        TEXT,
  progress_notes     TEXT,
  completion_images  TEXT[] NOT NULL DEFAULT '{}',
  status             VARCHAR(15) NOT NULL DEFAULT 'ASSIGNED'
                     CHECK (status IN ('ASSIGNED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED')),
  assigned_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at       TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_tasks_assigned_open
  ON tasks (assigned_to) WHERE status NOT IN ('COMPLETED', 'CANCELLED');

-- 10. NEWS (Communication Management)
CREATE TABLE IF NOT EXISTS news (
  id          SERIAL PRIMARY KEY,
  title       VARCHAR(200) NOT NULL,
  content     TEXT NOT NULL,
  image_url   TEXT,
  author_id   INTEGER NOT NULL REFERENCES users(id),
  status      VARCHAR(15) NOT NULL DEFAULT 'PUBLISHED' CHECK (status IN ('PUBLISHED', 'HIDDEN')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 11. CHAT_ROOMS (Communication Management)
CREATE TABLE IF NOT EXISTS chat_rooms (
  id                 SERIAL PRIMARY KEY,
  resident_id        INTEGER NOT NULL REFERENCES users(id),
  assigned_staff_id  INTEGER REFERENCES users(id),
  last_message       TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 12. MESSAGES (Communication Management)
CREATE TABLE IF NOT EXISTS messages (
  id          SERIAL PRIMARY KEY,
  room_id     INTEGER NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
  sender_id   INTEGER NOT NULL REFERENCES users(id),
  text        TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 13. STAY_EXTENSIONS (Tenancy Management) - BR-17
CREATE TABLE IF NOT EXISTS stay_extensions (
  id                  SERIAL PRIMARY KEY,
  contract_id         INTEGER NOT NULL REFERENCES contracts(id),
  resident_id         INTEGER NOT NULL REFERENCES users(id),
  current_end_date    DATE NOT NULL,
  requested_end_date  DATE NOT NULL,
  reason              TEXT,
  status              VARCHAR(15) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
  reviewed_by         INTEGER REFERENCES users(id),
  reviewed_at         TIMESTAMPTZ,
  reject_reason       TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 14. PAYMENTS (Billing Management)
CREATE TABLE IF NOT EXISTS payments (
  id                SERIAL PRIMARY KEY,
  invoice_id        INTEGER NOT NULL REFERENCES invoices(id),
  resident_id       INTEGER NOT NULL REFERENCES users(id),
  payos_order_id    VARCHAR(100) NOT NULL UNIQUE,
  transaction_code  VARCHAR(100),
  amount            NUMERIC(12, 2) NOT NULL,
  payment_method    VARCHAR(50) NOT NULL DEFAULT 'PAYOS',
  status            VARCHAR(15) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'SUCCESS', 'FAILED', 'CANCELLED')),
  paid_at           TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 15. NOTIFICATIONS (Communication Management)
CREATE TABLE IF NOT EXISTS notifications (
  id            SERIAL PRIMARY KEY,
  user_id       INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title         VARCHAR(200) NOT NULL,
  body          TEXT NOT NULL,
  type          VARCHAR(20) NOT NULL CHECK (type IN ('NEWS', 'INVOICE', 'PAYMENT', 'TICKET', 'TASK', 'EXTENSION', 'ROOMMATE', 'SYSTEM')),
  reference_id  INTEGER,
  is_read       BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  read_at       TIMESTAMPTZ
);

-- 16. AUDIT_LOGS (Operational Staff Management) - BR-04
CREATE TABLE IF NOT EXISTS audit_logs (
  id              SERIAL PRIMARY KEY,
  actor_id        INTEGER NOT NULL REFERENCES users(id),
  target_user_id  INTEGER REFERENCES users(id),
  action          VARCHAR(50) NOT NULL, -- STAFF_CREATE, STAFF_UPDATE, STAFF_DEACTIVATE
  old_value       JSONB,
  new_value       JSONB,
  reason          VARCHAR(250),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_target ON audit_logs (target_user_id, created_at DESC);
