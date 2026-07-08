/**
 * Next.js Proxy (tên mới của Middleware từ Next 16) - CORS cho API
 *
 * Cho phép Flutter Web (localhost:4321) gọi API cross-origin khi dev.
 * Lưu ý: KHÁC với src/lib/middleware.ts (RBAC requireAuth cho route handler).
 *
 * Production: mobile app gọi trực tiếp không bị CORS; nếu deploy web thật
 * thì siết origin theo domain cụ thể thay vì phản chiếu origin.
 */

import { NextRequest, NextResponse } from 'next/server';

function corsHeaders(origin: string): Record<string, string> {
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
  };
}

export function proxy(req: NextRequest) {
  const origin = req.headers.get('origin') ?? '*';

  // Preflight
  if (req.method === 'OPTIONS') {
    return new NextResponse(null, { status: 204, headers: corsHeaders(origin) });
  }

  const res = NextResponse.next();
  for (const [key, value] of Object.entries(corsHeaders(origin))) {
    res.headers.set(key, value);
  }
  return res;
}

export const config = {
  matcher: '/api/:path*',
};
