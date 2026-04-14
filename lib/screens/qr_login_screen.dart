import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../services/session_service.dart';

class QrLoginScreen extends StatefulWidget {
  const QrLoginScreen({super.key});

  @override
  State<QrLoginScreen> createState() => _QrLoginScreenState();
}

class _QrLoginScreenState extends State<QrLoginScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.normal,
  );
  
  bool _isScanning = true;
  bool _isLoading = false;
  String? _scanToken;
  
  @override
  void initState() {
    super.initState();
    // 检查是否已登录
    if (!SessionService.isLoggedIn()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录账号后再使用扫码登录功能')),
        );
        Navigator.pop(context);
      });
    }
  }
  
  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
  
  void _handleDetection(BarcodeCapture capture) {
    if (!_isScanning) return;
    
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final barcode = barcodes.first;
    final qrContent = barcode.rawValue;
    
    if (qrContent != null) {
      _processQrContent(qrContent);
    }
  }
  
  void _processQrContent(String qrContent) {
    setState(() => _isScanning = false);
    
    try {
      String? scanToken;
      
      if (qrContent.startsWith('http')) {
        // URL 格式: http://xxx.com?scan_token=xxx
        final uri = Uri.parse(qrContent);
        scanToken = uri.queryParameters['scan_token'];
      } else {
        // 尝试解析为 JSON
        try {
          final json = jsonDecode(qrContent);
          scanToken = json['scan_token'] as String?;
        } catch (_) {
          // 非JSON格式，直接作为token
          scanToken = qrContent;
        }
      }
      
      if (scanToken == null || scanToken.isEmpty) {
        _showErrorAndResume('无效的登录二维码');
        return;
      }
      
      setState(() => _scanToken = scanToken);
      _showConfirmDialog(scanToken);
    } catch (e) {
      _showErrorAndResume('二维码解析失败');
    }
  }
  
  void _showErrorAndResume(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    setState(() {
      _isScanning = true;
      _scanToken = null;
    });
  }
  
  void _showConfirmDialog(String scanToken) {
    final email = SessionService.getCurrentUserEmail() ?? '未知用户';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('网页端请求登录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.devices, size: 64, color: Color(0xFF5E9ED6)),
            const SizedBox(height: 16),
            Text(
              '当前账号: $email',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              '点击确认后将自动登录网页端',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isScanning = true;
                _scanToken = null;
              });
            },
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : () => _confirmScanLogin(scanToken),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5E9ED6),
              foregroundColor: Colors.white,
            ),
            child: _isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('确认登录'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _confirmScanLogin(String scanToken) async {
    final email = SessionService.getCurrentUserEmail();
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录账号')),
      );
      Navigator.pop(context);
      Navigator.pop(this.context);
      return;
    }
    
    setState(() => _isLoading = true);
    
    final response = await AuthApiService.scanLogin(
      scanToken: scanToken,
      email: email,
      action: 'confirm',
    );
    
    setState(() => _isLoading = false);
    
    if (response.status == 'success') {
      Navigator.pop(context); // 关闭对话框
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(
          content: Text('登录确认成功！'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(this.context); // 返回上一页
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message ?? '登录确认失败')),
      );
      Navigator.pop(context); // 关闭对话框
      setState(() {
        _isScanning = true;
        _scanToken = null;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫码登录网页端'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _scannerController.toggleTorch(),
            tooltip: '闪光灯',
          ),
        ],
      ),
      body: Column(
        children: [
          // 扫描区域
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _handleDetection,
                ),
                // 扫描框
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF5E9ED6),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                // 提示文字
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _isScanning ? '请将二维码对准扫描框' : '正在处理...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 说明区域
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '使用说明',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildStepItem('1. 在网页端打开登录页面'),
                  _buildStepItem('2. 点击网页端的"扫码登录"按钮'),
                  _buildStepItem('3. 使用本页面扫描网页端的二维码'),
                  _buildStepItem('4. 确认登录后网页端将自动登录'),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '扫码登录可快速在网页端登录当前账号',
                            style: TextStyle(color: Colors.blue[700], fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStepItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF5E9ED6), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
