/**
 * Unit test TicketService (Module 4: UC18-UC23) - mock repository, không cần DB.
 * Khóa các bất biến máy trạng thái sự cố (BR-40) dễ hồi quy:
 * - ASSIGNED chỉ được đặt qua luồng phân công (UC21); CHẶN set thủ công ở UC20
 *   để không tạo ticket "Đã phân công" mà không có ai được giao. (bug đã sửa)
 * - Chỉ cho bước nhảy trạng thái hợp lệ (BR-40).
 * - Hủy ticket -> purge ảnh (BR-38).
 * - AT4: không đổi gì thì không lưu.
 */

import { beforeEach, describe, expect, it, vi } from 'vitest';

import { deleteImagesBatch } from '@/lib/cloudinary';
import * as notificationRepo from '@/repositories/notification.repository';
import * as ticketRepo from '@/repositories/ticket.repository';
import * as ticketService from '@/services/ticket.service';

vi.mock('@/repositories/ticket.repository');
vi.mock('@/repositories/task.repository');
vi.mock('@/repositories/notification.repository');
vi.mock('@/services/firebase.service');
vi.mock('@/lib/cloudinary');
vi.mock('@/lib/db', () => ({
  withTransaction: (fn: (client: unknown) => unknown) => fn({ query: vi.fn() }),
  query: vi.fn(),
}));

/** Dựng 1 dòng chi tiết sự cố (TicketDetailRow) tối thiểu để service map được. */
function makeTicketRow(overrides: Record<string, unknown> = {}) {
  return {
    id: 1,
    apartment_id: 3,
    resident_id: 10,
    category: 'PLUMBING',
    description: 'Rò rỉ nước vòi rửa chén',
    before_images: [],
    status: 'PENDING',
    internal_notes: null,
    created_at: new Date(2026, 5, 1),
    updated_at: new Date(2026, 5, 1),
    unit_number: 'P.502',
    resident_name: 'Nguyen Van A',
    resident_phone: '0901234567',
    assignee_name: null,
    task_id: null,
    task_assigned_to: null,
    task_assignee_name: null,
    task_title: null,
    task_status: null,
    task_assigned_at: null,
    task_completed_at: null,
    ...overrides,
  } as any;
}

beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(notificationRepo.createNotificationsBulk).mockResolvedValue(undefined as any);
  vi.mocked(notificationRepo.getActiveDeviceTokens).mockResolvedValue([]);
});

describe('updateTicketStatus - UC20 máy trạng thái (BR-40)', () => {
  it('CHẶN chuyển thủ công sang "Đã phân công" (ASSIGNED chỉ qua UC21)', async () => {
    vi.mocked(ticketRepo.findTicketDetailById).mockResolvedValue(
      makeTicketRow({ status: 'PENDING' }),
    );

    await expect(
      ticketService.updateTicketStatus(1, { status: 'ASSIGNED' }),
    ).rejects.toMatchObject({
      status: 400,
      message: expect.stringContaining('phân công'),
    });
    // Không được ghi DB: không có ticket "đã phân công" mà không ai làm
    expect(ticketRepo.updateTicketStatus).not.toHaveBeenCalled();
  });

  it('Chặn bước nhảy trạng thái không hợp lệ: PENDING -> RESOLVED', async () => {
    vi.mocked(ticketRepo.findTicketDetailById).mockResolvedValue(
      makeTicketRow({ status: 'PENDING' }),
    );

    await expect(
      ticketService.updateTicketStatus(1, { status: 'RESOLVED' }),
    ).rejects.toMatchObject({ status: 400 });
    expect(ticketRepo.updateTicketStatus).not.toHaveBeenCalled();
  });

  it('AT4: không đổi trạng thái và không có ghi chú -> 400', async () => {
    vi.mocked(ticketRepo.findTicketDetailById).mockResolvedValue(
      makeTicketRow({ status: 'PENDING' }),
    );

    await expect(
      ticketService.updateTicketStatus(1, { status: 'PENDING' }),
    ).rejects.toMatchObject({ status: 400 });
    expect(ticketRepo.updateTicketStatus).not.toHaveBeenCalled();
  });

  it('Hủy ticket: đổi CANCELLED và purge ảnh trên Cloudinary (BR-38)', async () => {
    vi.mocked(ticketRepo.findTicketDetailById)
      .mockResolvedValueOnce(
        makeTicketRow({ status: 'PENDING', before_images: ['https://img/a.jpg'] }),
      )
      .mockResolvedValueOnce(makeTicketRow({ status: 'CANCELLED', before_images: [] }));
    vi.mocked(ticketRepo.updateTicketStatus).mockResolvedValue(undefined as any);
    vi.mocked(deleteImagesBatch).mockResolvedValue(undefined as any);

    const result = await ticketService.updateTicketStatus(1, { status: 'CANCELLED' });

    expect(ticketRepo.updateTicketStatus).toHaveBeenCalledWith(1, 'CANCELLED', null, true);
    expect(deleteImagesBatch).toHaveBeenCalledWith(['https://img/a.jpg']);
    expect(result.status).toBe('CANCELLED');
  });

  it('Chuyển hợp lệ PROCESSING -> RESOLVED, không purge ảnh', async () => {
    vi.mocked(ticketRepo.findTicketDetailById)
      .mockResolvedValueOnce(makeTicketRow({ status: 'PROCESSING' }))
      .mockResolvedValueOnce(makeTicketRow({ status: 'RESOLVED' }));
    vi.mocked(ticketRepo.updateTicketStatus).mockResolvedValue(undefined as any);

    const result = await ticketService.updateTicketStatus(1, { status: 'RESOLVED' });

    expect(ticketRepo.updateTicketStatus).toHaveBeenCalledWith(1, 'RESOLVED', null, false);
    expect(deleteImagesBatch).not.toHaveBeenCalled();
    expect(result.status).toBe('RESOLVED');
  });
});
