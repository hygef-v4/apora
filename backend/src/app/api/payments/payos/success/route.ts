import { NextRequest, NextResponse } from 'next/server';

/**
 * GET /api/payments/payos/success - Route nhận chuyển hướng từ PayOS sau khi thanh toán thành công.
 * Trả về trang HTML thông báo đơn giản cho WebView mobile hoặc Trình duyệt web.
 */
export async function GET(req: NextRequest) {
  const searchParams = req.nextUrl.searchParams;
  const invoiceId = searchParams.get('invoiceId') || '';

  const html = `
    <!DOCTYPE html>
    <html lang="vi">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Thanh toán thành công</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
            margin: 0;
            background-color: #f8fafc;
            color: #1e293b;
          }
          .card {
            background: #ffffff;
            padding: 2rem;
            border-radius: 1rem;
            box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
            text-align: center;
            max-width: 380px;
            width: 90%;
          }
          .icon-container {
            width: 64px;
            height: 64px;
            background-color: #d1fae5;
            color: #10b981;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 1rem;
            font-size: 32px;
            font-weight: bold;
          }
          h2 {
            margin: 0 0 0.5rem 0;
            font-size: 1.25rem;
            color: #0f172a;
          }
          p {
            color: #64748b;
            font-size: 0.875rem;
            margin: 0;
            line-height: 1.5;
          }
        </style>
      </head>
      <body>
        <div class="card">
          <div class="icon-container">✓</div>
          <h2>Thanh toán thành công!</h2>
          <p>Hóa đơn ${invoiceId ? `#${invoiceId}` : ''} đã được xử lý. Đang hoàn tất giao dịch...</p>
        </div>
      </body>
    </html>
  `;

  return new NextResponse(html, {
    status: 200,
    headers: { 'Content-Type': 'text/html; charset=utf-8' },
  });
}
