/// Hàm hỗ trợ mask số CCCD / Giấy tờ tùy thân theo BR-08 (Profile View Data Masking).
/// Chỉ hiển thị 4 số cuối (ví dụ: `********5678`), trừ trường hợp đã bị anonymize (`MASK_...`).
String maskCccdNumber(String? cccd) {
  if (cccd == null || cccd.trim().isEmpty) return 'Không có';
  final trimmed = cccd.trim();
  if (trimmed.startsWith('MASK_')) return trimmed;
  if (trimmed.length <= 4) return trimmed;
  return '*' * (trimmed.length - 4) + trimmed.substring(trimmed.length - 4);
}
