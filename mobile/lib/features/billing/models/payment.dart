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
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as int,
      invoiceId: json['invoice_id'] as int,
      residentId: json['resident_id'] as int,
      payosOrderId: json['payos_order_id'] as String,
      transactionCode: json['transaction_code'] as String?,
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String,
      status: json['status'] as String,
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
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
    };
  }
}
