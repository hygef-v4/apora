/**
 * Dev Database - PostgreSQL nhúng (embedded-postgres, không cần cài đặt/Docker)
 *
 * Chạy: npm run db:dev  (giữ terminal mở - Ctrl+C để tắt)
 * - Lần đầu: tự init cluster vào db/pgdata/ + tạo database "apora"
 * - Mỗi lần chạy: apply schema.sql + seed.sql (idempotent - IF NOT EXISTS / ON CONFLICT)
 * - Kết nối: postgresql://postgres:postgres@localhost:5433/apora
 *
 * CHỈ DÙNG CHO DEV LOCAL. Môi trường thật dùng Supabase (xem .env.example).
 */

import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import EmbeddedPostgres from 'embedded-postgres';
import pg from 'pg';

const dir = path.dirname(fileURLToPath(import.meta.url));
const dataDir = path.join(dir, 'pgdata');
const PORT = 5433;
const DB_NAME = 'apora';
const CONNECTION = `postgresql://postgres:postgres@localhost:${PORT}/${DB_NAME}`;

const firstRun = !existsSync(path.join(dataDir, 'PG_VERSION'));

const server = new EmbeddedPostgres({
  databaseDir: dataDir,
  user: 'postgres',
  password: 'postgres',
  port: PORT,
  persistent: true,
  // Windows initdb mặc định lấy locale WIN1252 -> lỗi 22P05 với tiếng Việt.
  // Ép UTF-8 + locale C để lưu được dữ liệu tiếng Việt trong seed.
  initdbFlags: ['--encoding=UTF8', '--locale=C'],
});

if (firstRun) {
  console.log('[dev-db] Lần chạy đầu - đang khởi tạo cluster...');
  await server.initialise();
}

await server.start();
if (firstRun) {
  await server.createDatabase(DB_NAME);
}

// Apply schema + seed (an toàn khi chạy lại)
const client = new pg.Client({ connectionString: CONNECTION });
await client.connect();
await client.query(readFileSync(path.join(dir, 'schema.sql'), 'utf8'));
await client.query(readFileSync(path.join(dir, 'seed.sql'), 'utf8'));
const { rows } = await client.query('SELECT phone_number, full_name, roles FROM users ORDER BY id');
await client.end();

console.log('==============================================');
console.log(`[dev-db] ✅ Database sẵn sàng: ${CONNECTION}`);
console.log('[dev-db] Tài khoản seed (mật khẩu: Apora@123):');
for (const row of rows) {
  console.log(`  - ${row.phone_number}  ${row.full_name}  [${row.roles}]`);
}
console.log('[dev-db] Nhấn Ctrl+C để tắt database.');
console.log('==============================================');

async function shutdown() {
  console.log('\n[dev-db] Đang tắt database...');
  await server.stop();
  process.exit(0);
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
