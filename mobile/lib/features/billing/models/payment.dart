class Payment {
  final int id;
  final int invoiceId;
  final int residentId;
  final String payosOrderId;
  final String? transactionCode;
  final double amount;
  final String paymentMethod;
  final String status; // 'PENDING', 'SUCCESS', 'FAILED', 'CANCELLED'
  final DateTime? paidAt;
  final DateTime createdAt;
  final String? unitNumber;
  final String? monthYear;
  final String? residentName;

  Payment({
    required this.id,
    required this.invoiceId,
    required this.residentId,
    required this.payosOrderId,
    this.transactionCode,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    this.paidAt,
    required this.createdAt,
    this.unitNumber,
    this.monthYear,
    this.residentName,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as int,
      invoiceId: json['invoice_id'] as int,
      residentId: json['resident_id'] as int,
      payosOrderId: json['payos_order_id'] as String,
      transactionCode: json['transaction_code'] as String?,
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      paymentMethod: json['payment_method'] as String,
      status: json['status'] as String,
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      unitNumber: json['unit_number'] as String?,
      monthYear: json['month_year'] as String?,
      residentName: json['resident_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'resident_id': residentId,
      'payos_order_id': payosOrderId,
      'transaction_code': transactionCode,
      'amount': amount,
      'payment_method': paymentMethod,
      'status': status,
      'paid_at': paidAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'unit_number': unitNumber,
      'month_year': monthYear,
      'resident_name': residentName,
    };
  }
}
