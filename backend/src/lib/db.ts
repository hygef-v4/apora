/**
 * Database Connection - PostgreSQL via Supabase Pooler
 *
 * Kết nối tới PostgreSQL thông qua connection string trong .env
 * Sử dụng Transaction Pool (port 6543) cho Serverless (Vercel)
 * Sử dụng raw query thay vì ORM
 *
 * @see https://supabase.com/docs/guides/database/connecting-to-postgres
 */

import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

export const query = (text: string, params?: any[]) => {
  return pool.query(text, params);
};

export const getClient = () => {
  return pool.connect();
};
