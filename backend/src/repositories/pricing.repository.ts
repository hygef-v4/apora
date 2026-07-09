import { query } from '@/lib/db';

export interface PricingSetting {
  id: number;
  electricity_rate: number;
  water_rate: number;
  mgmt_fee: number;
  effective_from: Date;
  created_by: number;
  created_at: Date;
}

/**
 * Lấy đơn giá điện, nước, phí quản lý hoạt động tại thời điểm cụ thể.
 * Mặc định lấy đơn giá mới nhất hiện tại.
 */
export async function findActivePricing(atDate?: Date): Promise<PricingSetting | null> {
  const targetDate = atDate || new Date();
  const res = await query(
    `SELECT * FROM pricing_settings
     WHERE effective_from <= $1
     ORDER BY effective_from DESC
     LIMIT 1`,
    [targetDate]
  );

  if (res.rows.length === 0) {
    return null;
  }

  // Chuyển đổi dữ liệu số sang kiểu Number (Postgres numeric được trả về dạng String để tránh mất an toàn số thực)
  return {
    id: res.rows[0].id,
    electricity_rate: Number(res.rows[0].electricity_rate),
    water_rate: Number(res.rows[0].water_rate),
    mgmt_fee: Number(res.rows[0].mgmt_fee),
    effective_from: new Date(res.rows[0].effective_from),
    created_by: res.rows[0].created_by,
    created_at: new Date(res.rows[0].created_at),
  };
}

/**
 * Thêm một bản ghi đơn giá mới (tự động áp dụng từ thời điểm tạo).
 */
export async function insertPricingSetting(
  electricityRate: number,
  waterRate: number,
  mgmtFee: number,
  createdBy: number
): Promise<PricingSetting> {
  const res = await query(
    `INSERT INTO pricing_settings (electricity_rate, water_rate, mgmt_fee, created_by)
     VALUES ($1, $2, $3, $4)
     RETURNING *`,
    [electricityRate, waterRate, mgmtFee, createdBy]
  );

  return {
    id: res.rows[0].id,
    electricity_rate: Number(res.rows[0].electricity_rate),
    water_rate: Number(res.rows[0].water_rate),
    mgmt_fee: Number(res.rows[0].mgmt_fee),
    effective_from: new Date(res.rows[0].effective_from),
    created_by: res.rows[0].created_by,
    created_at: new Date(res.rows[0].created_at),
  };
}
