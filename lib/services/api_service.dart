import 'package:dio/dio.dart';
import '../models/auth_models.dart';
import '../models/data_model.dart';

/// API配置
class ApiConfig {
  // 主服务器地址
  static const String baseUrl = 'http://1.92.98.95/';
  
  // 认证API地址
  static const String authBaseUrl = 'http://1.92.98.95/';
}

/// HTTP客户端
class HttpClient {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
  ));

  static Dio get instance => _dio;
}

/// 认证API服务
class AuthApiService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.authBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  /// 发送验证码
  static Future<AuthResponse> sendVerificationCode(String email) async {
    try {
      final response = await _dio.post(
        'email_api.php?action=send_code',
        data: {'email': email},
      );
      return AuthResponse.fromJson(response.data);
    } catch (e) {
      return AuthResponse(
        status: 'error',
        message: '网络错误: ${e.toString()}',
      );
    }
  }

  /// 用户注册
  static Future<AuthResponse> register({
    required String email,
    required String password,
    required String code,
  }) async {
    try {
      final response = await _dio.post(
        'email_api.php?action=register',
        data: {
          'email': email,
          'password': password,
          'code': code,
        },
      );
      return AuthResponse.fromJson(response.data);
    } catch (e) {
      return AuthResponse(
        status: 'error',
        message: '网络错误: ${e.toString()}',
      );
    }
  }

  /// 用户登录
  static Future<AuthResponse> login({
    required String email,
    required String loginType,
    required String credential,
  }) async {
    try {
      final response = await _dio.post(
        'email_api.php?action=login',
        data: {
          'email': email,
          'loginType': loginType,
          'credential': credential,
        },
      );
      return AuthResponse.fromJson(response.data);
    } catch (e) {
      return AuthResponse(
        status: 'error',
        message: '网络错误: ${e.toString()}',
      );
    }
  }

  /// 设置密码（新用户）
  static Future<AuthResponse> setPassword({
    required String email,
    required String password,
    required String token,
  }) async {
    try {
      final response = await _dio.post(
        'email_api.php?action=set_password',
        data: {
          'email': email,
          'password': password,
          'token': token,
        },
      );
      return AuthResponse.fromJson(response.data);
    } catch (e) {
      return AuthResponse(
        status: 'error',
        message: '网络错误: ${e.toString()}',
      );
    }
  }

  /// 生成扫码登录二维码
  static Future<AuthResponse> generateQrCode() async {
    try {
      final response = await _dio.get('email_api.php?action=generate_qr');
      return AuthResponse.fromJson(response.data);
    } catch (e) {
      return AuthResponse(
        status: 'error',
        message: '网络错误: ${e.toString()}',
      );
    }
  }

  /// 扫码登录确认/取消
  static Future<AuthResponse> scanLogin({
    required String scanToken,
    required String email,
    required String action,
  }) async {
    try {
      final response = await _dio.post(
        'email_api.php?action=scan_login',
        data: {
          'scan_token': scanToken,
          'email': email,
          'action': action,
        },
      );
      return AuthResponse.fromJson(response.data);
    } catch (e) {
      return AuthResponse(
        status: 'error',
        message: '网络错误: ${e.toString()}',
      );
    }
  }

  /// 检查扫码状态
  static Future<ScanStatusResponse> checkScanStatus(String scanToken) async {
    try {
      final response = await _dio.get(
        'email_api.php?action=check_scan_status',
        queryParameters: {'scan_token': scanToken},
      );
      return ScanStatusResponse.fromJson(response.data);
    } catch (e) {
      return ScanStatusResponse(
        status: 'error',
        message: '网络错误: ${e.toString()}',
      );
    }
  }

  /// 验证Token
  static Future<AuthResponse> verifyToken(String token) async {
    try {
      final response = await _dio.get(
        'email_api.php?action=verify_token',
        queryParameters: {'token': token},
      );
      return AuthResponse.fromJson(response.data);
    } catch (e) {
      return AuthResponse(
        status: 'error',
        message: '网络错误: ${e.toString()}',
      );
    }
  }
}

/// 传感器数据API服务
class SensorApiService {
  static final Dio _dio = HttpClient.instance;

  /// 获取传感器数据（按时间范围）
  static Future<ResponseModel> getSensorDataByTimeRange({
    required String patient,
    required String startTime,
    required String endTime,
    String sensorType = 'sensor1',
  }) async {
    try {
      final response = await _dio.get(
        'influxdb_query.php',
        queryParameters: {
          'patient': patient,
          'startTime': startTime,
          'endTime': endTime,
          'sensorType': sensorType,
        },
      );
      return ResponseModel.fromJson(response.data);
    } catch (e) {
      return ResponseModel(
        status: 'error',
        message: '网络错误: ${e.toString()}',
        data: [],
      );
    }
  }

  /// 获取实时数据（最近5分钟）
  static Future<ResponseModel> getRealtimeData({
    required String patient,
    String sensorType = 'sensor1',
  }) async {
    final now = DateTime.now();
    final startTime = now.subtract(const Duration(minutes: 5));
    
    final format = (DateTime dt) => 
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    
    return getSensorDataByTimeRange(
      patient: patient,
      startTime: format(startTime),
      endTime: format(now),
      sensorType: sensorType,
    );
  }
}
