import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_models.dart';
import '../models/patient_model.dart';

/// 会话管理服务
class SessionService {
  static const String _keyUserSession = 'user_session';
  static const String _keyRememberPassword = 'remember_password';
  static const String _keySavedEmail = 'saved_email';
  static const String _keySavedPassword = 'saved_password';
  static const String _keyPatients = 'patients';

  static SharedPreferences? _prefs;

  /// 初始化
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('SessionService not initialized. Call init() first.');
    }
    return _prefs!;
  }

  /// 保存用户会话
  static Future<void> saveSession(UserSession session) async {
    await prefs.setString(_keyUserSession, jsonEncode(session.toJson()));
  }

  /// 获取用户会话
  static UserSession? getSession() {
    final json = prefs.getString(_keyUserSession);
    if (json == null) return null;
    try {
      return UserSession.fromJson(jsonDecode(json));
    } catch (e) {
      return null;
    }
  }

  /// 清除会话（退出登录）
  static Future<void> clearSession() async {
    await prefs.remove(_keyUserSession);
  }

  /// 是否已登录
  static bool isLoggedIn() {
    return getSession() != null;
  }

  /// 获取当前用户邮箱
  static String? getCurrentUserEmail() {
    return getSession()?.email;
  }

  /// 获取当前Token
  static String? getToken() {
    return getSession()?.token;
  }

  /// 保存记住密码设置
  static Future<void> saveRememberPassword({
    required String email,
    required String password,
  }) async {
    await prefs.setBool(_keyRememberPassword, true);
    await prefs.setString(_keySavedEmail, email);
    await prefs.setString(_keySavedPassword, password);
  }

  /// 清除记住密码
  static Future<void> clearRememberPassword() async {
    await prefs.setBool(_keyRememberPassword, false);
    await prefs.remove(_keySavedEmail);
    await prefs.remove(_keySavedPassword);
  }

  /// 获取保存的邮箱
  static String? getSavedEmail() {
    return prefs.getString(_keySavedEmail);
  }

  /// 获取保存的密码
  static String? getSavedPassword() {
    return prefs.getString(_keySavedPassword);
  }

  /// 是否记住密码
  static bool isRememberPassword() {
    return prefs.getBool(_keyRememberPassword) ?? false;
  }

  /// 保存患者列表
  static Future<void> savePatients(List<PatientModel> patients) async {
    final jsonList = patients.map((p) => p.toJson()).toList();
    await prefs.setString(_keyPatients, jsonEncode(jsonList));
  }

  /// 获取患者列表
  static List<PatientModel> getPatients() {
    final json = prefs.getString(_keyPatients);
    if (json == null) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(json);
      return jsonList.map((j) => PatientModel.fromJson(j)).toList();
    } catch (e) {
      return [];
    }
  }

  /// 添加患者
  static Future<void> addPatient(PatientModel patient) async {
    final patients = getPatients();
    // 检查是否已存在
    if (!patients.any((p) => p.name == patient.name)) {
      patients.add(patient);
      await savePatients(patients);
    }
  }

  /// 删除患者
  static Future<void> removePatient(String name) async {
    final patients = getPatients();
    patients.removeWhere((p) => p.name == name);
    await savePatients(patients);
  }

  /// 根据名称获取患者
  static PatientModel? getPatientByName(String name) {
    final patients = getPatients();
    try {
      return patients.firstWhere((p) => p.name == name);
    } catch (e) {
      return null;
    }
  }
}
