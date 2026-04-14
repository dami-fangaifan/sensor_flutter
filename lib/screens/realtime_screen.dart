import 'dart:async';
import 'dart:math';
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
  int _sensorCount = 3;
  
  // 图表控制
  final int _maxDisplayPoints = 50; // 最多显示的数据点
  int _displayPointCount = 30; // 当前显示的数据点数
  double _minY = 0;
  double _maxY = 100;
  
  // 统计数据
  double _avgValue = 0;
  double _maxValue = 0;
  double _minValue = 0;
  
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
          _calculateStatistics();
        } else {
          _currentPressure = '-- kPa';
          _dataStatus = '暂无数据';
        }
      });
    }
  }
  
  void _calculateStatistics() {
    if (_dataList.isEmpty) return;
    
    final values = _dataList.map((d) => d.value).toList();
    _avgValue = values.reduce((a, b) => a + b) / values.length;
    _maxValue = values.reduce(max);
    _minValue = values.reduce(min);
    
    // 设置Y轴范围，留出一些边距
    _minY = (_minValue - 5).clamp(0, double.infinity);
    _maxY = _maxValue + 5;
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
                  if (value != null) {
                    final patient = _patients.firstWhere((p) => p.name == value);
                    _sensorCount = patient.sensorCount;
                  }
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '实时数据图表',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (_dataList.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '共 ${_dataList.length} 个数据点',
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            
            // 显示点数控制
            if (_selectedPatient != null && _dataList.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Text('显示点数: ', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _displayPointCount.toDouble(),
                        min: 10,
                        max: _maxDisplayPoints.toDouble(),
                        divisions: 4,
                        label: '$_displayPointCount',
                        onChanged: (value) {
                          setState(() => _displayPointCount = value.toInt());
                        },
                      ),
                    ),
                    Text('$_displayPointCount', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            
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
    // 取最近的N个数据点
    final displayData = _dataList.length > _displayPointCount
        ? _dataList.sublist(_dataList.length - _displayPointCount)
        : _dataList;

    final spots = displayData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value);
    }).toList();

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        // 允许滑动查看
      },
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            verticalInterval: max(1, displayData.length / 5),
            horizontalInterval: max(1, (_maxY - _minY) / 5),
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey[300]!,
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: Colors.grey[200]!,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                interval: max(1, displayData.length / 5),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < displayData.length) {
                    final showLabel = index == 0 || 
                        index == displayData.length - 1 ||
                        index % max(1, (displayData.length / 5).floor()) == 0;
                    if (showLabel) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          displayData[index].formattedTime.substring(0, 5),
                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                        ),
                      );
                    }
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (displayData.length - 1).toDouble(),
          minY: _minY,
          maxY: _maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF5E9ED6),
              barWidth: 2.5,
              dotData: FlDotData(
                show: displayData.length <= 20,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 3,
                    color: const Color(0xFF5E9ED6),
                    strokeWidth: 1,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF5E9ED6).withOpacity(0.15),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  if (index >= 0 && index < displayData.length) {
                    final data = displayData[index];
                    return LineTooltipItem(
                      '${data.formattedTime}\n${data.value.toStringAsFixed(2)} kPa',
                      const TextStyle(color: Colors.white, fontSize: 11),
                    );
                  }
                  return null;
                }).toList();
              },
            ),
          ),
        ),
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
            Row(
              children: [
                _buildStatItem('平均值', '${_avgValue.toStringAsFixed(2)} kPa', Colors.blue, Icons.analytics),
                const SizedBox(width: 12),
                _buildStatItem('最大值', '${_maxValue.toStringAsFixed(2)} kPa', Colors.green, Icons.arrow_upward),
                const SizedBox(width: 12),
                _buildStatItem('最小值', '${_minValue.toStringAsFixed(2)} kPa', Colors.orange, Icons.arrow_downward),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[600], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '数据波动范围: ${(_maxValue - _minValue).toStringAsFixed(2)} kPa',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
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
  
  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
