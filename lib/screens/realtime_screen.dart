import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../models/data_model.dart';
import '../models/patient_model.dart';

class RealtimeScreen extends StatefulWidget {
  const RealtimeScreen({super.key});

  @override
  State<RealtimeScreen> createState() => _RealtimeScreenState();
}

class _RealtimeScreenState extends State<RealtimeScreen> {
  String? _selectedPatient;
  String _selectedSensor = 'sensor1';
  List<PatientModel> _patients = [];
  List<DataModel> _dataList = [];
  bool _isLoading = false;
  String _currentPressure = '-- kPa';
  String _lastUpdate = '--:--:--';
  String _dataStatus = '等待数据...';
  Color _statusColor = Colors.grey;
  
  Timer? _refreshTimer;
  final int _sensorCount = 3;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _loadPatients() {
    setState(() {
      _patients = SessionService.getPatients();
    });
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchRealtimeData();
    });
    _fetchRealtimeData();
    setState(() {
      _dataStatus = '实时监测中';
      _statusColor = Colors.green;
    });
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    setState(() {
      _dataStatus = '等待数据...';
      _statusColor = Colors.grey;
    });
  }

  Future<void> _fetchRealtimeData() async {
    if (_selectedPatient == null || _isLoading) return;

    setState(() => _isLoading = true);

    final response = await SensorApiService.getRealtimeData(
      patient: _selectedPatient!,
      sensorType: _selectedSensor,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.status == 'success' && response.data.isNotEmpty) {
          _dataList = response.data;
          final latest = _dataList.last;
          _currentPressure = '${latest.value.toStringAsFixed(2)} kPa';
          _lastUpdate = latest.formattedTime;
        } else {
          _currentPressure = '-- kPa';
          _dataStatus = '暂无数据';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('实时数据'),
        actions: [
          if (_selectedPatient != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchRealtimeData,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 患者信息卡片
            _buildPatientCard(),
            const SizedBox(height: 12),
            
            // 实时状态卡片
            _buildStatusCard(),
            const SizedBox(height: 12),
            
            // 图表卡片
            _buildChartCard(),
            const SizedBox(height: 12),
            
            // 数据分析卡片
            _buildAnalysisCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '患者信息',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            // 患者选择
            DropdownButtonFormField<String>(
              value: _selectedPatient,
              decoration: const InputDecoration(
                labelText: '患者姓名',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('请选择患者')),
                ..._patients.map((p) => DropdownMenuItem(
                  value: p.name,
                  child: Text(p.name),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedPatient = value;
                  _dataList = [];
                  _currentPressure = '-- kPa';
                  _lastUpdate = '--:--:--';
                });
                if (value != null) {
                  _startAutoRefresh();
                } else {
                  _stopAutoRefresh();
                }
              },
            ),
            const SizedBox(height: 12),
            
            // 传感器选择
            DropdownButtonFormField<String>(
              value: _selectedSensor,
              decoration: const InputDecoration(
                labelText: '测量部位',
                border: OutlineInputBorder(),
              ),
              items: List.generate(
                _sensorCount,
                (i) => DropdownMenuItem(
                  value: 'sensor${i + 1}',
                  child: Text('传感器 ${i + 1}'),
                ),
              ),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedSensor = value);
                  if (_selectedPatient != null) {
                    _fetchRealtimeData();
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '实时状态',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '最后更新: $_lastUpdate',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text('当前压力', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        Text(
                          _currentPressure,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5E9ED6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey[300],
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text('数据状态', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        Text(
                          _dataStatus,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '实时数据图表',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 250,
              child: _selectedPatient == null
                  ? _buildEmptyState('请选择患者', '选择患者后将显示实时数据')
                  : _dataList.isEmpty
                      ? _buildEmptyState('暂无数据', '请稍候...')
                      : _buildLineChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    final spots = _dataList.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          gridVerticalData: FlGridData(show: false),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < _dataList.length && index % 10 == 0) {
                  return Text(
                    _dataList[index].formattedTime.substring(0, 5),
                    style: const TextStyle(fontSize: 8),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF5E9ED6),
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF5E9ED6).withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildAnalysisCard() {
    if (_selectedPatient == null || _dataList.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '数据分析',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '正在开发中...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '更多数据分析功能即将上线',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
