/// 患者数据模型

class PatientModel {
  final String name;
  final int sensorCount;
  final String deviceCode;
  final DateTime createdAt;
  final String? notes;

  PatientModel({
    required this.name,
    this.sensorCount = 3,
    this.deviceCode = '',
    DateTime? createdAt,
    this.notes,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sensorCount': sensorCount,
      'deviceCode': deviceCode,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'notes': notes,
    };
  }

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      name: json['name'] ?? '',
      sensorCount: json['sensorCount'] ?? 3,
      deviceCode: json['deviceCode'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
          : null,
      notes: json['notes'],
    );
  }

  PatientModel copyWith({
    String? name,
    int? sensorCount,
    String? deviceCode,
    DateTime? createdAt,
    String? notes,
  }) {
    return PatientModel(
      name: name ?? this.name,
      sensorCount: sensorCount ?? this.sensorCount,
      deviceCode: deviceCode ?? this.deviceCode,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
    );
  }
}

/// 设备验证响应
class PatientDeviceValidationResponse {
  final bool isValid;
  final String patientName;
  final int sensorCount;

  PatientDeviceValidationResponse({
    required this.isValid,
    this.patientName = '',
    this.sensorCount = 0,
  });

  factory PatientDeviceValidationResponse.fromJson(Map<String, dynamic> json) {
    return PatientDeviceValidationResponse(
      isValid: json['is_valid'] ?? false,
      patientName: json['patient_name'] ?? '',
      sensorCount: json['sensor_count'] ?? 0,
    );
  }
}
