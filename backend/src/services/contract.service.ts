/**
 * ContractService - Business Logic cho Module 2: Tenancy & Stay Extension (UC06-UC09)
 *
 * Business Rules chính:
 * - BR-12: chỉ hợp đồng ACTIVE mới tính thời hạn còn lại / được xin gia hạn.
 * - BR-13: số ngày còn lại tính động mỗi lần load, không lưu DB.
 * - BR-14: ngày kết thúc mới phải SAU ngày kết thúc hiện tại.
 * - BR-15: lý do gia hạn bắt buộc 10-500 ký tự.
 * - BR-16: chỉ MANAGER/LANDLORD được xem/duyệt yêu cầu (enforce ở route).
 * - BR-17: duyệt gia hạn chạy trong 1 transaction (đổi status + dời end_date).
 * - BR-18: cư dân nhận thông báo khi yêu cầu được duyệt/từ chối.
 * - BR-23: cư dân chỉ thao tác trên hợp đồng của chính mình.
 *
 * @see docs/PRM393_SoftwareDesign_Group5.docx - Module 2
 */

import { withTransaction } from '@/lib/db';
import { HttpError } from '@/lib/middleware';
import * as contractRepo from '@/repositories/contract.repository';
import * as extensionRepo from '@/repositories/stay-extension.repository';
import * as notificationRepo from '@/repositories/notification.repository';
import { sendPushNotification } from '@/services/firebase.service';
import {
  MyContractResponse,
  StayExtensionDetail,
  StayExtensionListItem,
  StayExtensionStatus,
} from '@/types';

/** BR-15: ràng buộc độ dài lý do gia hạn. */
const REASON_MIN = 10;
const REASON_MAX = 500;
/** FID-12: lý do từ chối tối đa 500 ký tự. */
const REJECT_REASON_MAX = 500;

const EXTENSION_STATUSES: StayExtensionStatus[] = ['PENDING', 'APPROVED', 'REJECTED'];

/** So sánh theo NGÀY (bỏ giờ) - date từ pg là Date, input là YYYY-MM-DD. */
function toDateOnly(value: Date | string): Date {
  const d = new Date(value);
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

/**
 * Format Date -> 'YYYY-MM-DD' theo giờ LOCAL. Không dùng toISOString()
 * vì pg trả DATE về là Date lúc 00:00 local; đổi sang UTC sẽ lùi 1 ngày.
 */
function formatDateLocal(value: Date | string): string {
  const d = toDateOnly(value);
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${d.getFullYear()}-${mm}-${dd}`;
}

/** BR-13: số ngày còn lại = end_date - hôm nay (làm tròn lên, tối thiểu 0). */
function calcRemainingDays(endDate: Date): number {
  const msPerDay = 24 * 60 * 60 * 1000;
  const diff = toDateOnly(endDate).getTime() - toDateOnly(new Date()).getTime();
  return Math.max(0, Math.round(diff / msPerDay));
}

function toListItem(row: extensionRepo.StayExtensionRow): StayExtensionListItem {
  return {
    id: row.id,
    residentName: row.resident_name,
    unitNumber: row.unit_number,
    floor: row.floor,
    currentEndDate: row.current_end_date,
    requestedEndDate: row.requested_end_date,
    status: row.status,
    createdAt: row.created_at,
    reviewedAt: row.reviewed_at,
  };
}

function toDetail(row: extensionRepo.StayExtensionDetailRow): StayExtensionDetail {
  return {
    ...toListItem(row),
    contractId: row.contract_id,
    residentPhone: row.resident_phone,
    contractStartDate: row.contract_start_date,
    contractEndDate: row.contract_end_date,
    contractStatus: row.contract_status,
    baseRent: Number(row.base_rent_snapshot),
    reason: row.reason,
    rejectReason: row.reject_reason,
    reviewedByName: row.reviewed_by_name,
  };
}

// ==========================================
// UC06: View Contract
// ==========================================

/**
 * UC06: hợp đồng của chính user (BR-23 - query theo userId từ JWT).
 * - AT1: hợp đồng EXPIRED vẫn trả về, client tự ẩn phần thời hạn còn lại.
 * - AT2: chưa có hợp đồng -> contract = null, kèm căn hộ đứng tên (nếu có).
 */
export async function getMyContract(userId: number): Promise<MyContractResponse> {
  // Lazy expire: dọn hợp đồng quá hạn trước khi đọc (thay cho cron job)
  await contractRepo.expireOverdueContracts();
  const row = await contractRepo.findLatestContractByResident(userId);
  if (!row) {
    const apartment = await contractRepo.findApartmentByOwner(userId);
    return {
      apartment: apartment
        ? {
            id: apartment.id,
            unitNumber: apartment.unit_number,
            floor: apartment.floor,
            status: apartment.status,
          }
        : null,
      contract: null,
    };
  }

  const isActive = row.status === 'ACTIVE';
  const pending = isActive ? await extensionRepo.findPendingByContract(row.id) : null;
  return {
    apartment: {
      id: row.apartment_id,
      unitNumber: row.unit_number,
      floor: row.floor,
      status: row.apartment_status,
    },
    contract: {
      id: row.id,
      startDate: row.start_date,
      endDate: row.end_date,
      baseRent: Number(row.base_rent_snapshot),
      status: row.status,
      // BR-12: EXPIRED không hiển thị thời hạn còn lại
      remainingDays: isActive ? calcRemainingDays(row.end_date) : null,
      pendingExtensionId: pending?.id ?? null,
    },
  };
}

// ==========================================
// UC07: Request Stay Extension
// ==========================================

/**
 * UC07: cư dân gửi yêu cầu gia hạn cho hợp đồng ACTIVE của CHÍNH MÌNH.
 * Validate: BR-12 (hợp đồng ACTIVE), BR-14 (ngày mới > ngày kết thúc hiện tại),
 * BR-15 (lý do 10-500 ký tự); chặn gửi trùng khi còn yêu cầu PENDING.
 */
export async function requestExtension(
  userId: number,
  input: { requestedEndDate?: string; reason?: string },
): Promise<StayExtensionListItem> {
  const reason = input.reason?.trim() ?? '';
  if (reason.length < REASON_MIN || reason.length > REASON_MAX) {
    throw new HttpError(
      400,
      `Lý do gia hạn phải từ ${REASON_MIN} đến ${REASON_MAX} ký tự.`,
    );
  }

  const rawDate = input.requestedEndDate ?? '';
  if (!/^\d{4}-\d{2}-\d{2}$/.test(rawDate) || isNaN(new Date(rawDate).getTime())) {
    throw new HttpError(400, 'Ngày kết thúc mới không hợp lệ (định dạng YYYY-MM-DD).');
  }

  // Lazy expire trước khi kiểm tra BR-12: hợp đồng quá hạn không được gia hạn
  await contractRepo.expireOverdueContracts();
  const contract = await contractRepo.findLatestContractByResident(userId);
  if (!contract || contract.status !== 'ACTIVE') {
    // BR-12: không có hợp đồng ACTIVE thì không được xin gia hạn
    throw new HttpError(400, 'Bạn không có hợp đồng đang hiệu lực để gia hạn.');
  }

  // BR-14: ngày mới phải SAU ngày kết thúc hiện tại (so theo ngày)
  if (toDateOnly(rawDate).getTime() <= toDateOnly(contract.end_date).getTime()) {
    throw new HttpError(
      400,
      'Ngày kết thúc mới phải sau ngày kết thúc hợp đồng hiện tại.',
    );
  }

  const pending = await extensionRepo.findPendingByContract(contract.id);
  if (pending) {
    throw new HttpError(
      409,
      'Bạn đã có một yêu cầu gia hạn đang chờ duyệt. Vui lòng đợi kết quả.',
    );
  }

  const row = await extensionRepo.insertExtension({
    contractId: contract.id,
    residentId: userId,
    currentEndDate: formatDateLocal(contract.end_date),
    requestedEndDate: rawDate,
    reason,
  });
  return toListItem(row);
}

// ==========================================
// UC08: View Stay Extension Requests
// ==========================================

/** UC08: danh sách yêu cầu gia hạn cho Manager/Landlord, lọc theo status. */
export async function getExtensions(filter: {
  status?: string;
}): Promise<StayExtensionListItem[]> {
  let status: StayExtensionStatus | undefined;
  if (filter.status) {
    if (!EXTENSION_STATUSES.includes(filter.status as StayExtensionStatus)) {
      throw new HttpError(400, 'Trạng thái lọc không hợp lệ.');
    }
    status = filter.status as StayExtensionStatus;
  }
  const rows = await extensionRepo.findExtensions(status);
  return rows.map(toListItem);
}

/** UC09: chi tiết yêu cầu gia hạn (màn duyệt). */
export async function getExtensionDetail(id: number): Promise<StayExtensionDetail> {
  // Lazy expire để màn duyệt thấy đúng trạng thái hợp đồng (AT3)
  await contractRepo.expireOverdueContracts();
  const row = await extensionRepo.findExtensionDetailById(id);
  if (!row) {
    throw new HttpError(404, 'Không tìm thấy yêu cầu gia hạn.');
  }
  return toDetail(row);
}

// ==========================================
// UC09: Approve/Reject Stay Extension
// ==========================================

/**
 * UC09: Manager/Landlord duyệt hoặc từ chối yêu cầu gia hạn.
 * - APPROVE (BR-17): đổi status + dời contracts.end_date trong 1 transaction;
 *   hợp đồng không còn ACTIVE (AT3) hoặc yêu cầu đã được duyệt bởi người
 *   khác -> rollback, trả 409.
 * - REJECT (AT1/AT2): bắt buộc lý do từ chối, không đụng hợp đồng.
 * - BR-18: gửi thông báo cho cư dân sau khi chốt (best-effort).
 */
export async function reviewExtension(
  reviewerId: number,
  extensionId: number,
  input: { action?: string; rejectReason?: string },
): Promise<StayExtensionDetail> {
  if (input.action !== 'APPROVE' && input.action !== 'REJECT') {
    throw new HttpError(400, 'Hành động không hợp lệ (APPROVE hoặc REJECT).');
  }

  const rejectReason = input.rejectReason?.trim() ?? '';
  if (input.action === 'REJECT') {
    if (!rejectReason) {
      throw new HttpError(400, 'Cần nhập lý do từ chối yêu cầu.');
    }
    if (rejectReason.length > REJECT_REASON_MAX) {
      throw new HttpError(400, `Lý do từ chối tối đa ${REJECT_REASON_MAX} ký tự.`);
    }
  }

  // Lazy expire trước khi duyệt: hợp đồng quá hạn sẽ chặn APPROVE ở AT3
  await contractRepo.expireOverdueContracts();
  const extension = await extensionRepo.findExtensionDetailById(extensionId);
  if (!extension) {
    throw new HttpError(404, 'Không tìm thấy yêu cầu gia hạn.');
  }
  if (extension.status !== 'PENDING') {
    throw new HttpError(409, 'Yêu cầu này đã được xử lý trước đó.');
  }

  if (input.action === 'APPROVE') {
    // AT3: kiểm tra sớm cho message rõ ràng; transaction bên dưới vẫn là chốt chặn
    if (extension.contract_status !== 'ACTIVE') {
      throw new HttpError(
        409,
        'Không thể duyệt: hợp đồng liên quan đã không còn hiệu lực.',
      );
    }
    const requestedDate = formatDateLocal(extension.requested_end_date);
    // BR-17: cả hai UPDATE cùng thành công hoặc cùng rollback
    await withTransaction(async (client) => {
      const marked = await extensionRepo.markReviewed(
        client,
        extensionId,
        'APPROVED',
        reviewerId,
        null,
      );
      if (!marked) {
        throw new HttpError(409, 'Yêu cầu này vừa được người khác xử lý.');
      }
      const extended = await contractRepo.extendContractEndDate(
        client,
        extension.contract_id,
        requestedDate,
      );
      if (!extended) {
        throw new HttpError(
          409,
          'Không thể duyệt: hợp đồng liên quan đã không còn hiệu lực.',
        );
      }
    });
  } else {
    await withTransaction(async (client) => {
      const marked = await extensionRepo.markReviewed(
        client,
        extensionId,
        'REJECTED',
        reviewerId,
        rejectReason,
      );
      if (!marked) {
        throw new HttpError(409, 'Yêu cầu này vừa được người khác xử lý.');
      }
    });
  }

  // BR-18: báo kết quả cho cư dân (không chặn response)
  notifyResidentReviewed(extension, input.action, rejectReason).catch((error) => {
    console.error('[ContractService] Gửi thông báo kết quả gia hạn thất bại:', error);
  });

  const updated = await extensionRepo.findExtensionDetailById(extensionId);
  return toDetail(updated!);
}

/** BR-18: thông báo in-app + FCM cho cư dân khi yêu cầu được duyệt/từ chối. */
async function notifyResidentReviewed(
  extension: extensionRepo.StayExtensionDetailRow,
  action: 'APPROVE' | 'REJECT',
  rejectReason: string,
): Promise<void> {
  const approved = action === 'APPROVE';
  const title = approved
    ? 'Yêu cầu gia hạn được chấp thuận'
    : 'Yêu cầu gia hạn bị từ chối';
  const newDate = new Date(extension.requested_end_date);
  const dateStr = `${String(newDate.getDate()).padStart(2, '0')}/${String(
    newDate.getMonth() + 1,
  ).padStart(2, '0')}/${newDate.getFullYear()}`;
  const body = approved
    ? `Hợp đồng phòng ${extension.unit_number} đã được gia hạn đến ${dateStr}.`
    : `Yêu cầu gia hạn phòng ${extension.unit_number} bị từ chối. Lý do: ${rejectReason}`;

  await notificationRepo.createNotificationsBulk(
    [extension.resident_id],
    title,
    body,
    'EXTENSION',
    extension.id,
  );
  const tokens = await notificationRepo.getActiveDeviceTokens([extension.resident_id]);
  await sendPushNotification(tokens, title, body, {
    type: 'EXTENSION',
    referenceId: String(extension.id),
  });
}
