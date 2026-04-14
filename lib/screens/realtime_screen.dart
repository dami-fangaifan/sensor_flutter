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
  List<DataModel> _chartData = []; // 用于图表显示的数据（采样后）
  bool _isLoading = false;
  String _currentPressure = '-- kPa';
  String _lastUpdate = '--:--:--';
  String _dataStatus = '等待数据...';
  Color _statusColor = Colors.grey;
  
  Timer? _refreshTimer;
  int _sensorCount = 3;
  
  // 图表缩放控制
  double _minY = 0;
  double _maxY = 100;
  double _minX = 0;
  double _maxX = 99;
  
  // 固定显示100个数据点
  static const int _chartPointCount = 100;
  
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
          _processChartData();
        } else {
          _currentPressure = '-- kPa';
          _dataStatus = '暂无数据';
        }
      });
    }
  }
  
  /// 处理图表数据：固定显示100个点，通过平均步长采样
  void _processChartData() {
    if (_dataList.isEmpty) {
      _chartData = [];
      return;
    }
    
    if (_dataList.length <= _chartPointCount) {
      // 数据不足100个，直接使用
      _chartData = List.from(_dataList);
    } else {
      // 数据超过100个，通过平均步长采样
      _chartData = _sampleData(_dataList, _chartPointCount);
    }
    
    // 根据数据调整Y轴范围
    if (_chartData.isNotEmpty) {
      final values = _chartData.map((d) => d.value).toList();
      _minY = (values.reduce(min) - 5).clamp(0, double.infinity);
      _maxY = values.reduce(max) + 5;
    }
  }
  
  /// 通过平均步长采样数据
  List<DataModel> _sampleData(List<DataModel> data, int targetCount) {
    if (data.length <= targetCount) return data;
    
    final result = <DataModel>[];
    final step = data.length / targetCount;
    
    for (int i = 0; i < targetCount; i++) {
      final index = (i * step).floor();
      if (index < data.length) {
        result.add(data[index]);
      }
    }
    
    return result;
  }
  
  /// 获取状态描述
  String _getStatusText(double value) {
    if (value > 15) {
      return '高风险';
    } else if (value > 10) {
      return '偏高';
    } else {
      return '正常';
    }
  }
  
  Color _getStatusColor(double value) {
    if (value > 15) {
      return Colors.red;
    } else if (value > 10) {
      return Colors.orange;
    } else {
      return Colors.green;
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
            const SizedBox(height: 12),

            // 详细数据卡片
            _buildDetailDataCard(),
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
                  _chartData = [];
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
            const Text(
              '实时数据图表',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '可双指缩放查看',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 280,
              child: _selectedPatient == null
                  ? _buildEmptyState('请选择患者', '选择患者后将显示实时数据')
                  : _chartData.isEmpty
                      ? _buildEmptyState('暂无数据', '请稍候...')
                      : _buildLineChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    final spots = _chartData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value);
    }).toList();

    return GestureDetector(
      onDoubleTap: () {
        // 双击重置缩放
        setState(() {
          _minX = 0;
          _maxX = (_chartData.length - 1).toDouble();
        });
      },
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 3.0,
        constrained: false,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              verticalInterval: max(1, _chartData.length / 8),
              horizontalInterval: max(1, (_maxY - _minY) / 6),
              getDrawingHorizontalLine: (value) {
                return FlLine(color: Colors.grey[300]!, strokeWidth: 1);
              },
              getDrawingVerticalLine: (value) {
                return FlLine(color: Colors.grey[200]!, strokeWidth: 1);
              },
            ),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 50,
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
                  interval: max(1, _chartData.length / 6),
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < _chartData.length) {
                      // 显示时间戳
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _chartData[index].formattedTime.substring(0, 5),
                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: (_chartData.length - 1).toDouble(),
            minY: _minY,
            maxY: _maxY,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: const Color(0xFF5E9ED6),
                barWidth: 2.5,
                dotData: FlDotData(
                  show: _chartData.length <= 30,
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
                    if (index >= 0 && index < _chartData.length) {
                      final data = _chartData[index];
                      // 显示完整日期和时间
                      return LineTooltipItem(
                        '${data.timestamp}\n${data.value.toStringAsFixed(2)} kPa',
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

  Widget _buildDetailDataCard() {
    if (_selectedPatient == null || _dataList.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // 显示最近10条数据
    final displayData = _dataList.length > 10 
        ? _dataList.sublist(_dataList.length - 10) 
        : _dataList;
    
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
                  '详细数据',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // 表头
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      '时间',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '压力值',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '状态',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            
            // 数据列表
            ...displayData.reversed.map((data) => _buildDataRow(data)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDataRow(DataModel data) {
    final statusText = _getStatusText(data.value);
    final statusColor = _getStatusColor(data.value);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              data.formattedTime,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              data.value.toStringAsFixed(2),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (statusText == '高风险')
                  const Icon(Icons.warning, color: Colors.red, size: 14),
                Text(
                  statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
