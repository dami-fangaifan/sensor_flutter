/// 认证相关的数据模型

/// 通用认证响应
class AuthResponse {
  final String status;
  final String message;
  final AuthData? data;

  AuthResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      data: json['data'] != null ? AuthData.fromJson(json['data']) : null,
    );
  }

  bool get isSuccess => status == 'success';
}

/// 认证数据
class AuthData {
  final String email;
  final String token;
  final String qrCode;
  final String scanToken;
  final int expiresAt;
  final bool isNewUser;

  AuthData({
    this.email = '',
    this.token = '',
    this.qrCode = '',
    this.scanToken = '',
    this.expiresAt = 0,
    this.isNewUser = false,
  });

  factory AuthData.fromJson(Map<String, dynamic> json) {
    return AuthData(
      email: json['email'] ?? '',
      token: json['token'] ?? '',
      qrCode: json['qr_code'] ?? '',
      scanToken: json['scan_token'] ?? '',
      expiresAt: json['expires_at'] ?? 0,
      isNewUser: json['is_new_user'] ?? false,
    );
  }
}

/// 扫码状态响应
class ScanStatusResponse {
  final String status;
  final String message;
  final ScanStatusData? data;

  ScanStatusResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory ScanStatusResponse.fromJson(Map<String, dynamic> json) {
    return ScanStatusResponse(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      data: json['data'] != null ? ScanStatusData.fromJson(json['data']) : null,
    );
  }
}

/// 扫码状态数据
class ScanStatusData {
  final String state;
  final String email;
  final String token;

  ScanStatusData({
    required this.state,
    this.email = '',
    this.token = '',
  });

  factory ScanStatusData.fromJson(Map<String, dynamic> json) {
    return ScanStatusData(
      state: json['state'] ?? '',
      email: json['email'] ?? '',
      token: json['token'] ?? '',
    );
  }
}

/// 用户会话
class UserSession {
  final String email;
  final String token;
  final int loginTime;

  UserSession({
    required this.email,
    required this.token,
    int? loginTime,
  }) : loginTime = loginTime ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'token': token,
      'loginTime': loginTime,
    };
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      email: json['email'] ?? '',
      token: json['token'] ?? '',
      loginTime: json['loginTime'],
    );
  }
}
