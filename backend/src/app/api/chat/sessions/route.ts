import { NextRequest } from 'next/server';
import { jsonSuccess, jsonError, requireAuth } from '@/lib/middleware';
import * as chatService from '@/services/chat.service';

export async function GET(req: NextRequest) {
  try {
    const user = await requireAuth(req);
    const isManager = user.roles.includes('MANAGER') || user.roles.includes('LANDLORD');
    
    const url = new URL(req.url);
    const limit = parseInt(url.searchParams.get('limit') || '20', 10);
    const offset = parseInt(url.searchParams.get('offset') || '0', 10);

    const sessions = await chatService.getChatSessions(user.id, isManager, limit, offset);
    return jsonSuccess('Lấy danh sách chat thành công', sessions);
  } catch (error) {
    return jsonError(error);
  }
}
