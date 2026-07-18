import { NextRequest } from 'next/server';
import { jsonSuccess, jsonError, requireAuth } from '@/lib/middleware';
import * as chatService from '@/services/chat.service';

export async function PATCH(req: NextRequest) {
  try {
    const user = await requireAuth(req);
    const isManager = user.roles.includes('MANAGER') || user.roles.includes('LANDLORD');
    
    const body = await req.json();
    const partnerId = body.partner_id ? parseInt(body.partner_id.toString(), 10) : null;

    await chatService.markAsRead(user.id, isManager, partnerId);
    return jsonSuccess('Đã xem tin nhắn');
  } catch (error) {
    return jsonError(error);
  }
}
