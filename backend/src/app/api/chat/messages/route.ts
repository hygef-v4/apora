import { NextRequest } from 'next/server';
import { jsonSuccess, jsonError, requireAuth } from '@/lib/middleware';
import * as chatService from '@/services/chat.service';

export async function GET(req: NextRequest) {
  try {
    const user = await requireAuth(req);
    const isManager = user.roles.includes('MANAGER') || user.roles.includes('LANDLORD');
    
    const url = new URL(req.url);
    const partnerIdStr = url.searchParams.get('partner_id');
    const partnerId = partnerIdStr ? parseInt(partnerIdStr, 10) : null;
    const limit = parseInt(url.searchParams.get('limit') || '50', 10);
    const offset = parseInt(url.searchParams.get('offset') || '0', 10);

    const messages = await chatService.getMessages(user.id, isManager, partnerId, limit, offset);
    return jsonSuccess('Lấy tin nhắn thành công', messages);
  } catch (error) {
    return jsonError(error);
  }
}

export async function POST(req: NextRequest) {
  try {
    const user = await requireAuth(req);
    const isManager = user.roles.includes('MANAGER') || user.roles.includes('LANDLORD');
    
    const formData = await req.formData();
    const receiverIdStr = formData.get('receiver_id');
    const receiverId = receiverIdStr ? parseInt(receiverIdStr.toString(), 10) : null;
    const content = formData.get('content') as string | null;
    const image = formData.get('image') as File | null;

    const message = await chatService.sendMessage(user.id, isManager, receiverId, content, image);
    return jsonSuccess('Gửi tin nhắn thành công', message);
  } catch (error) {
    return jsonError(error);
  }
}
