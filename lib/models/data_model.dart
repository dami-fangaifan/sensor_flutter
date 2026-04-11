/// 传感器数据模型

class DataModel {
  final String timestamp;
  final double value;
  final String patient;
  final String sensorType;
  final String device;

  DataModel({
    required this.timestamp,
    required this.value,
    this.patient = '',
    this.sensorType = '',
    this.device = '',
  });

  factory DataModel.fromJson(Map<String, dynamic> json) {
    return DataModel(
      timestamp: json['timestamp'] ?? '',
      value: (json['value'] ?? 0).toDouble(),
      patient: json['patient'] ?? '',
      sensorType: json['sensor_type'] ?? '',
      device: json['device'] ?? '',
    );
  }

  /// 获取格式化的时间 (HH:mm:ss)
  String get formattedTime {
    try {
      final parts = timestamp.split(' ');
      if (parts.length >= 2) {
        return parts[1].substring(0, 8);
      }
      return timestamp;
    } catch (e) {
      return timestamp;
    }
  }

  /// 获取格式化的日期 (yyyy-MM-dd)
  String get formattedDate {
    try {
      final parts = timestamp.split(' ');
      if (parts.isNotEmpty) {
        return parts[0];
      }
      return timestamp;
    } catch (e) {
      return timestamp;
    }
  }
}

/// API响应模型
class ResponseModel {
  final String status;
  final String message;
  final List<DataModel> data;

  ResponseModel({
    required this.status,
    required this.message,
    required this.data,
  });

  factory ResponseModel.fromJson(Map<String, dynamic> json) {
    var dataList = <DataModel>[];
    if (json['data'] != null && json['data'] is List) {
      dataList = (json['data'] as List)
          .map((item) => DataModel.fromJson(item))
          .toList();
    }
    return ResponseModel(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      data: dataList,
    );
  }
}
