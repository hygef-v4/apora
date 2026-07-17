import { query, withTransaction } from '@/lib/db';
import { HttpError } from '@/lib/middleware';
import { triggerChatEvent } from './pusher.service';
import { sendPushNotification } from './firebase.service';
import { uploadImage } from '@/lib/cloudinary';

export async function getChatSessions(userId: number, isManager: boolean, limit: number = 20, offset: number = 0) {
  if (isManager) {
    const sql = `
      SELECT 
        cr.resident_id,
        u.full_name as resident_name,
        cr.last_message,
        cr.updated_at,
        (SELECT COUNT(*) FROM messages m WHERE m.room_id = cr.id AND m.is_read = FALSE AND m.sender_id != $1) as unread_count,
        (SELECT is_image FROM messages m WHERE m.room_id = cr.id ORDER BY m.created_at DESC LIMIT 1) as is_last_message_image
      FROM chat_rooms cr
      JOIN users u ON cr.resident_id = u.id
      ORDER BY cr.updated_at DESC
      LIMIT $2 OFFSET $3
    `;
    const result = await query(sql, [userId, limit, offset]);
    return result.rows.map(r => ({
      resident_id: r.resident_id,
      resident_name: r.resident_name,
      last_message: r.last_message,
      updated_at: r.updated_at,
      unread_count: parseInt(r.unread_count, 10),
      is_last_message_image: r.is_last_message_image || false
    }));
  } else {
    const sql = `
      SELECT 
        cr.resident_id,
        u.full_name as resident_name,
        cr.last_message,
        cr.updated_at,
        (SELECT COUNT(*) FROM messages m WHERE m.room_id = cr.id AND m.is_read = FALSE AND m.sender_id != $1) as unread_count,
        (SELECT is_image FROM messages m WHERE m.room_id = cr.id ORDER BY m.created_at DESC LIMIT 1) as is_last_message_image
      FROM chat_rooms cr
      JOIN users u ON cr.resident_id = u.id
      WHERE cr.resident_id = $1
    `;
    const result = await query(sql, [userId]);
    return result.rows.map(r => ({
      resident_id: r.resident_id,
      resident_name: r.resident_name,
      last_message: r.last_message,
      updated_at: r.updated_at,
      unread_count: parseInt(r.unread_count, 10),
      is_last_message_image: r.is_last_message_image || false
    }));
  }
}

export async function getMessages(userId: number, isManager: boolean, partnerId: number | null, limit: number = 50, offset: number = 0) {
  let targetResidentId = isManager ? partnerId : userId;
  
  if (!targetResidentId) {
    throw new HttpError(400, 'partner_id is required for managers');
  }

  const roomResult = await query('SELECT id FROM chat_rooms WHERE resident_id = $1', [targetResidentId]);
  if (roomResult.rows.length === 0) {
    return [];
  }
  const roomId = roomResult.rows[0].id;

  const sql = `
    SELECT 
      m.id,
      m.sender_id,
      m.text as content,
      m.is_image,
      m.is_read,
      m.created_at,
      u.full_name as sender_name,
      u.roles[1] as sender_role
    FROM messages m
    JOIN users u ON m.sender_id = u.id
    WHERE m.room_id = $1
    ORDER BY m.created_at DESC
    LIMIT $2 OFFSET $3
  `;
  const result = await query(sql, [roomId, limit, offset]);
  return result.rows;
}

export async function sendMessage(senderId: number, isManager: boolean, receiverId: number | null, content: string | null, imageFile: File | null) {
  let targetResidentId = isManager ? receiverId : senderId;
  
  if (!targetResidentId) {
    throw new HttpError(400, 'receiver_id is required when manager sends a message');
  }

  if (!content && !imageFile) {
    throw new HttpError(400, 'Message content or image is required');
  }

  let finalContent = content || '';
  let isImage = false;

  if (imageFile) {
    const arrayBuffer = await imageFile.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);
    finalContent = await uploadImage(buffer, 'chat');
    isImage = true;
  }

  return await withTransaction(async (client) => {
    let roomResult = await client.query('SELECT id FROM chat_rooms WHERE resident_id = $1', [targetResidentId]);
    let roomId: number;
    if (roomResult.rows.length === 0) {
      roomResult = await client.query(
        'INSERT INTO chat_rooms (resident_id, last_message, updated_at) VALUES ($1, $2, NOW()) RETURNING id',
        [targetResidentId, isImage ? '[Hình ảnh]' : finalContent]
      );
      roomId = roomResult.rows[0].id;
    } else {
      roomId = roomResult.rows[0].id;
      await client.query(
        'UPDATE chat_rooms SET last_message = $1, updated_at = NOW() WHERE id = $2',
        [isImage ? '[Hình ảnh]' : finalContent, roomId]
      );
    }

    const insertMsgSql = `
      INSERT INTO messages (room_id, sender_id, text, is_image, is_read, created_at)
      VALUES ($1, $2, $3, $4, FALSE, NOW())
      RETURNING id, sender_id, text as content, is_image, is_read, created_at
    `;
    const msgResult = await client.query(insertMsgSql, [roomId, senderId, finalContent, isImage]);
    const message = msgResult.rows[0];

    const userResult = await client.query('SELECT full_name, roles FROM users WHERE id = $1', [senderId]);
    const senderData = userResult.rows[0];
    
    const responseMessage = {
      ...message,
      sender_name: senderData.full_name,
      sender_role: senderData.roles[0],
      receiver_id: receiverId
    };

    const channelName = isManager ? `private-chat-${targetResidentId}` : 'management-chat';
    await triggerChatEvent(channelName, 'new-message', responseMessage);

    if (isManager) {
      const tokensRes = await client.query("SELECT token FROM device_tokens WHERE user_id = $1 AND status = 'ACTIVE' AND revoked_at IS NULL", [targetResidentId]);
      const tokens = tokensRes.rows.map(r => r.token);
      if (tokens.length > 0) {
        await sendPushNotification(tokens, 'Tin nhắn mới từ Ban Quản Lý', isImage ? '[Hình ảnh]' : finalContent, { type: 'CHAT', senderId: senderId.toString() });
      }
    } else {
      const tokensRes = await client.query("SELECT dt.token FROM device_tokens dt JOIN users u ON dt.user_id = u.id WHERE ('MANAGER' = ANY(u.roles) OR 'LANDLORD' = ANY(u.roles)) AND dt.status = 'ACTIVE' AND dt.revoked_at IS NULL");
      const tokens = tokensRes.rows.map(r => r.token);
      if (tokens.length > 0) {
        await sendPushNotification(tokens, `Tin nhắn mới từ phòng ${senderData.full_name}`, isImage ? '[Hình ảnh]' : finalContent, { type: 'CHAT', senderId: senderId.toString(), residentId: targetResidentId.toString() });
      }
    }

    return responseMessage;
  });
}

export async function markAsRead(userId: number, isManager: boolean, partnerId: number | null) {
  let targetResidentId = isManager ? partnerId : userId;
  
  if (!targetResidentId) {
    throw new HttpError(400, 'partner_id is required');
  }

  const roomResult = await query('SELECT id FROM chat_rooms WHERE resident_id = $1', [targetResidentId]);
  if (roomResult.rows.length === 0) {
    return; 
  }
  const roomId = roomResult.rows[0].id;

  await query('UPDATE messages SET is_read = TRUE WHERE room_id = $1 AND sender_id != $2', [roomId, userId]);
}
