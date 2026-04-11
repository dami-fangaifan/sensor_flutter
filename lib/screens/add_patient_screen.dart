import 'package:flutter/material.dart';
import '../models/patient_model.dart';
import '../services/session_service.dart';

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _deviceCodeController = TextEditingController();
  final _notesController = TextEditingController();
  int _sensorCount = 3;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _deviceCodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final patient = PatientModel(
      name: _nameController.text.trim(),
      sensorCount: _sensorCount,
      deviceCode: _deviceCodeController.text.trim(),
      notes: _notesController.text.trim().isNotEmpty 
          ? _notesController.text.trim() 
          : null,
    );

    await SessionService.addPatient(patient);

    if (mounted) {
      Navigator.of(context).pop(patient);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('添加患者'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 患者基本信息卡片
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '基本信息',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      
                      // 患者姓名
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '患者姓名 *',
                          hintText: '请输入患者姓名',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入患者姓名';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // 设备编号
                      TextFormField(
                        controller: _deviceCodeController,
                        decoration: const InputDecoration(
                          labelText: '设备编号',
                          hintText: '可选',
                          prefixIcon: Icon(Icons.devices),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // 传感器数量
                      Row(
                        children: [
                          const Text('传感器数量：'),
                          const SizedBox(width: 16),
                          IconButton(
                            onPressed: _sensorCount > 1
                                ? () => setState(() => _sensorCount--)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Container(
                            width: 40,
                            alignment: Alignment.center,
                            child: Text(
                              '$_sensorCount',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _sensorCount < 10
                                ? () => setState(() => _sensorCount++)
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // 备注卡片
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '备注',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: '可添加备注信息...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // 保存按钮
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
