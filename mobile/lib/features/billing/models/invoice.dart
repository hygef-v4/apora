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

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final mYear = json['month_year'] as String;
    final cAt = json['created_at'] as String?;
    
    return Invoice(
      id: json['id'] as int,
      contractId: json['contract_id'] as int,
      apartmentId: json['apartment_id'] as int,
      monthYear: mYear,
      prevElectricityIndex: (json['prev_electricity_index'] as num).toDouble(),
      currElectricityIndex: (json['curr_electricity_index'] as num).toDouble(),
      electricityConsumption: (json['electricity_consumption'] as num).toDouble(),
      prevWaterIndex: (json['prev_water_index'] as num).toDouble(),
      currWaterIndex: (json['curr_water_index'] as num).toDouble(),
      waterConsumption: (json['water_consumption'] as num).toDouble(),
      roomRentSnapshot: double.tryParse(json['room_rent_snapshot'].toString()) ?? 0.0,
      mgmtFeeSnapshot: double.tryParse(json['mgmt_fee_snapshot'].toString()) ?? 0.0,
      extraFee: double.tryParse(json['extra_fee'].toString()) ?? 0.0,
      extraFeeDescription: json['extra_fee_description'] as String?,
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0.0,
      status: json['status'] as String,
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : _parseDueDate(mYear, cAt),
      unitNumber: json['unit_number'] as String?,
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
      'extra_fee': extraFee,
      'extra_fee_description': extraFeeDescription,
      'total_amount': totalAmount,
      'status': status,
      'due_date': dueDate.toIso8601String(),
      'unit_number': unitNumber,
    };
  }
}
