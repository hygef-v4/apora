class Invoice {
  final int id;
  final int contractId;
  final int apartmentId;
  final String monthYear;
  final double prevElectricityIndex;
  final double currElectricityIndex;
  final double electricityConsumption;
  final double prevWaterIndex;
  final double currWaterIndex;
  final double waterConsumption;
  final double roomRentSnapshot;
  final double mgmtFeeSnapshot;
  final double electricityRateSnapshot;
  final double waterRateSnapshot;
  final double extraFee;
  final String? extraFeeDescription;
  final double totalAmount;
  final String status; // 'UNPAID', 'PAID'
  final DateTime dueDate;
  final String? unitNumber;

  Invoice({
    required this.id,
    required this.contractId,
    required this.apartmentId,
    required this.monthYear,
    required this.prevElectricityIndex,
    required this.currElectricityIndex,
    required this.electricityConsumption,
    required this.prevWaterIndex,
    required this.currWaterIndex,
    required this.waterConsumption,
    required this.roomRentSnapshot,
    required this.mgmtFeeSnapshot,
    required this.electricityRateSnapshot,
    required this.waterRateSnapshot,
    required this.extraFee,
    this.extraFeeDescription,
    required this.totalAmount,
    required this.status,
    required this.dueDate,
    this.unitNumber,
  });

  static DateTime _parseDueDate(String monthYear, String? createdAtStr) {
    try {
      final parts = monthYear.split('/');
      final month = int.parse(parts[0]);
      final year = int.parse(parts[1]);
      return DateTime(year, month + 1, 0);
    } catch (_) {
      if (createdAtStr != null) {
        return DateTime.parse(createdAtStr).add(const Duration(days: 10));
      }
      return DateTime.now().add(const Duration(days: 10));
    }
  }

  static double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final mYear = (json['month_year'] ?? json['monthYear'] ?? '').toString();
    final cAt = json['created_at']?.toString();
    
    return Invoice(
      id: json['id'] as int,
      contractId: json['contract_id'] ?? json['contractId'] ?? 0,
      apartmentId: json['apartment_id'] ?? json['apartmentId'] ?? 0,
      monthYear: mYear,
      prevElectricityIndex: _parseDouble(json['prev_electricity_index'] ?? json['prevElectricityIndex']),
      currElectricityIndex: _parseDouble(json['curr_electricity_index'] ?? json['currElectricityIndex']),
      electricityConsumption: _parseDouble(json['electricity_consumption'] ?? json['electricityConsumption']),
      prevWaterIndex: _parseDouble(json['prev_water_index'] ?? json['prevWaterIndex']),
      currWaterIndex: _parseDouble(json['curr_water_index'] ?? json['currWaterIndex']),
      waterConsumption: _parseDouble(json['water_consumption'] ?? json['waterConsumption']),
      roomRentSnapshot: _parseDouble(json['room_rent_snapshot'] ?? json['roomRentSnapshot']),
      mgmtFeeSnapshot: _parseDouble(json['mgmt_fee_snapshot'] ?? json['mgmtFeeSnapshot']),
      electricityRateSnapshot: _parseDouble(json['electricity_rate_snapshot'] ?? json['electricityRateSnapshot']),
      waterRateSnapshot: _parseDouble(json['water_rate_snapshot'] ?? json['waterRateSnapshot']),
      extraFee: _parseDouble(json['extra_fee'] ?? json['extraFee']),
      extraFeeDescription: json['extra_fee_description']?.toString(),
      totalAmount: _parseDouble(json['total_amount'] ?? json['totalAmount']),
      status: (json['status']?.toString() ?? 'UNPAID').toUpperCase().trim(),
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : _parseDueDate(mYear, cAt),
      unitNumber: json['unit_number']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contract_id': contractId,
      'apartment_id': apartmentId,
      'month_year': monthYear,
      'prev_electricity_index': prevElectricityIndex,
      'curr_electricity_index': currElectricityIndex,
      'electricity_consumption': electricityConsumption,
      'prev_water_index': prevWaterIndex,
      'curr_water_index': currWaterIndex,
      'water_consumption': waterConsumption,
      'room_rent_snapshot': roomRentSnapshot,
      'mgmt_fee_snapshot': mgmtFeeSnapshot,
      'electricity_rate_snapshot': electricityRateSnapshot,
      'water_rate_snapshot': waterRateSnapshot,
      'extra_fee': extraFee,
      'extra_fee_description': extraFeeDescription,
      'total_amount': totalAmount,
      'status': status,
      'due_date': dueDate.toIso8601String(),
      'unit_number': unitNumber,
    };
  }
}
