import 'package:flutter/material.dart';

/// Danh mục sự cố (UC19). Giá trị [value] LƯU DB phải khớp enum backend
/// TICKET_CATEGORIES = ['Điện','Nước','Nội thất','Khác'] nên giữ tiếng Việt;
/// chỉ [label] hiển thị là tiếng Anh theo wireframe.
class TicketCategory {
  const TicketCategory(this.value, this.label, this.icon);

  final String value; // gửi lên backend (không đổi)
  final String label; // hiển thị (tiếng Anh)
  final IconData icon;
}

const List<TicketCategory> kTicketCategories = [
  TicketCategory('Điện', 'Electricity', Icons.electrical_services),
  TicketCategory('Nước', 'Water', Icons.water_drop),
  TicketCategory('Nội thất', 'Furniture', Icons.chair),
  TicketCategory('Khác', 'Other', Icons.more_horiz),
];

/// Map cả giá trị backend (tiếng Việt) lẫn vài mã enum tiếng Anh có thể gặp
/// từ dữ liệu cũ/test sang nhãn hiển thị tiếng Anh; fallback giữ nguyên.
const Map<String, String> _extraLabels = {
  'ELECTRICAL': 'Electricity',
  'PLUMBING': 'Water',
  'FURNITURE': 'Furniture',
  'OTHER': 'Other',
};

const Map<String, IconData> _extraIcons = {
  'ELECTRICAL': Icons.electrical_services,
  'PLUMBING': Icons.water_drop,
  'FURNITURE': Icons.chair,
  'OTHER': Icons.more_horiz,
};

String ticketCategoryLabel(String value) {
  for (final c in kTicketCategories) {
    if (c.value == value) return c.label;
  }
  return _extraLabels[value] ?? value;
}

IconData ticketCategoryIcon(String value) {
  for (final c in kTicketCategories) {
    if (c.value == value) return c.icon;
  }
  return _extraIcons[value] ?? Icons.build_outlined;
}
