/**
 * Unit test ContractService (Module 2: UC06-UC09) - mock repository, không cần DB.
 * Tập trung bất biến nghiệp vụ dễ hồi quy của luồng duyệt gia hạn (UC09):
 * - BR-17: duyệt gia hạn = chốt duyệt + dời end_date CHUNG 1 transaction;
 *   nếu 1 vế thất bại thì cả hai ném lỗi, không chốt nửa vời.
 * - AT2: từ chối bắt buộc có lý do.
 * - AT3: hợp đồng không còn ACTIVE thì không duyệt được (409).
 * - Chống double-review: yêu cầu đã xử lý -> 409.
 */

import { beforeEach, describe, expect, it, vi } from 'vitest';

import * as contractRepo from '@/repositories/contract.repository';
import * as extensionRepo from '@/repositories/stay-extension.repository';
import * as notificationRepo from '@/repositories/notification.repository';
import * as contractService from '@/services/contract.service';

vi.mock('@/repositories/contract.repository');
vi.mock('@/repositories/stay-extension.repository');
vi.mock('@/repositories/notification.repository');
// Không khởi tạo Firebase Admin thật khi import service.
vi.mock('@/services/firebase.service');

// withTransaction chỉ cần gọi callback với 1 client giả (repo đã mock hết).
vi.mock('@/lib/db', () => ({
  withTransaction: (fn: (client: unknown) => unknown) => fn({ query: vi.fn() }),
  query: vi.fn(),
}));

/** Dựng 1 dòng chi tiết yêu cầu gia hạn (dùng Date theo local để tránh lệch TZ). */
function makeDetailRow(overrides: Record<string, unknown> = {}) {
  return {
    id: 1,
    contract_id: 10,
    resident_id: 5,
    current_end_date: new Date(2026, 11, 31),
    requested_end_date: new Date(2027, 5, 30),
    reason: 'Xin gia hạn thêm sáu tháng',
    status: 'PENDING',
    reviewed_by: null,
    reviewed_at: null,
    reject_reason: null,
    created_at: new Date(2026, 5, 1),
    resident_name: 'Nguyen Van A',
    unit_number: 'P.502',
    floor: 'Tầng 5',
    resident_phone: '0901234567',
    contract_start_date: new Date(2026, 0, 1),
    contract_end_date: new Date(2026, 11, 31),
    contract_status: 'ACTIVE',
    base_rent_snapshot: '5000000',
    reviewed_by_name: null,
    ...overrides,
  } as any;
}

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(contractRepo.expireOverdueContracts).mockResolvedValue(0);
  vi.mocked(notificationRepo.createNotificationsBulk).mockResolvedValue(undefined as any);
  vi.mocked(notificationRepo.getActiveDeviceTokens).mockResolvedValue([]);
});

describe('reviewExtension - UC09 duyệt/từ chối gia hạn', () => {
  it('APPROVE: chốt duyệt + dời end_date trong 1 transaction (BR-17)', async () => {
    vi.mocked(extensionRepo.findExtensionDetailById)
      .mockResolvedValueOnce(makeDetailRow()) // trước duyệt: PENDING + ACTIVE
      .mockResolvedValueOnce(
        makeDetailRow({ status: 'APPROVED', reviewed_by: 2, reviewed_by_name: 'Manager' }),
      ); // sau duyệt
    vi.mocked(extensionRepo.markReviewed).mockResolvedValue(true);
    vi.mocked(contractRepo.updateContractEndDate).mockResolvedValue(true);

    const result = await contractService.reviewExtension(2, 1, { action: 'APPROVE' });

    expect(extensionRepo.markReviewed).toHaveBeenCalledWith(
      expect.anything(),
      1,
      'APPROVED',
      2,
      null,
    );
    // BR-14/BR-17: dời end_date đúng ngày cư dân yêu cầu (định dạng YYYY-MM-DD local)
    expect(contractRepo.updateContractEndDate).toHaveBeenCalledWith(
      expect.anything(),
      10,
      '2027-06-30',
    );
    expect(result.status).toBe('APPROVED');
  });

  it('BR-17: nếu dời end_date thất bại thì cả transaction ném lỗi (không chốt nửa vời)', async () => {
    vi.mocked(extensionRepo.findExtensionDetailById).mockResolvedValue(makeDetailRow());
    vi.mocked(extensionRepo.markReviewed).mockResolvedValue(true);
    vi.mocked(contractRepo.updateContractEndDate).mockResolvedValue(false);

    await expect(
      contractService.reviewExtension(2, 1, { action: 'APPROVE' }),
    ).rejects.toMatchObject({ status: 409 });
  });

  it('AT3: hợp đồng không còn ACTIVE -> 409, không chốt duyệt', async () => {
    vi.mocked(extensionRepo.findExtensionDetailById).mockResolvedValue(
      makeDetailRow({ contract_status: 'EXPIRED' }),
    );

    await expect(
      contractService.reviewExtension(2, 1, { action: 'APPROVE' }),
    ).rejects.toMatchObject({ status: 409 });
    expect(extensionRepo.markReviewed).not.toHaveBeenCalled();
    expect(contractRepo.updateContractEndDate).not.toHaveBeenCalled();
  });

  it('Chống duyệt trùng: yêu cầu đã xử lý -> 409', async () => {
    vi.mocked(extensionRepo.findExtensionDetailById).mockResolvedValue(
      makeDetailRow({ status: 'APPROVED' }),
    );

    await expect(
      contractService.reviewExtension(2, 1, { action: 'APPROVE' }),
    ).rejects.toMatchObject({ status: 409 });
    expect(extensionRepo.markReviewed).not.toHaveBeenCalled();
  });

  it('AT2: REJECT thiếu lý do -> 400, không đụng transaction', async () => {
    await expect(
      contractService.reviewExtension(2, 1, { action: 'REJECT' }),
    ).rejects.toMatchObject({ status: 400 });
    expect(extensionRepo.markReviewed).not.toHaveBeenCalled();
  });

  it('REJECT hợp lệ: đánh dấu REJECTED, KHÔNG dời end_date hợp đồng', async () => {
    vi.mocked(extensionRepo.findExtensionDetailById)
      .mockResolvedValueOnce(makeDetailRow())
      .mockResolvedValueOnce(
        makeDetailRow({ status: 'REJECTED', reject_reason: 'Không đủ điều kiện' }),
      );
    vi.mocked(extensionRepo.markReviewed).mockResolvedValue(true);

    const result = await contractService.reviewExtension(2, 1, {
      action: 'REJECT',
      rejectReason: 'Không đủ điều kiện',
    });

    expect(extensionRepo.markReviewed).toHaveBeenCalledWith(
      expect.anything(),
      1,
      'REJECTED',
      2,
      'Không đủ điều kiện',
    );
    expect(contractRepo.updateContractEndDate).not.toHaveBeenCalled();
    expect(result.status).toBe('REJECTED');
  });

  it('Action không hợp lệ -> 400', async () => {
    await expect(
      contractService.reviewExtension(2, 1, { action: 'MAYBE' }),
    ).rejects.toMatchObject({ status: 400 });
  });
});
