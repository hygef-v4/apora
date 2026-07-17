/**
 * Database Connection - PostgreSQL via Supabase Pooler
 *
 * Kết nối tới PostgreSQL thông qua connection string trong .env
 * Sử dụng Transaction Pool (port 6543) cho Serverless (Vercel)
 * Sử dụng raw query thay vì ORM
 *
 * @see https://supabase.com/docs/guides/database/connecting-to-postgres
 */

import { Pool, PoolClient, QueryResult } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

/**
 * Nguồn thực thi query: pool (mặc định) hoặc PoolClient đang trong transaction.
 * Repository nhận tham số này để cùng một hàm chạy được cả trong lẫn ngoài
 * transaction (truyền client từ withTransaction vào).
 */
export interface Queryable {
  query(text: string, params?: unknown[]): Promise<QueryResult>;
}

export const query = (text: string, params?: any[]) => {
  return pool.query(text, params);
};

export const getClient = () => {
  return pool.connect();
};

/**
 * Chạy một khối lệnh trong 1 transaction (BEGIN → COMMIT / ROLLBACK khi lỗi).
 *
 * Dùng cho các thao tác phải nguyên tử (Module 4):
 * - UC20: cập nhật trạng thái ticket + ghi nội bộ trong cùng 1 bước.
 * - UC21: phân công ticket = đổi ticket sang ASSIGNED + tạo Task, không được nửa vời.
 *
 * Callback nhận `client` đã BEGIN sẵn - MỌI query trong transaction phải dùng
 * `client.query(...)` (không dùng `query()` toàn cục kẻo chạy ngoài transaction).
 */
export async function withTransaction<T>(
  fn: (client: PoolClient) => Promise<T>,
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}
