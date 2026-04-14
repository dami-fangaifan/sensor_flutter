import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../models/data_model.dart';
import '../models/patient_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String? _selectedPatient;
  String _selectedSensor = 'sensor1';
  List<PatientModel> _patients = [];
  List<DataModel> _dataList = [];
  List<DataModel> _chartData = []; // 用于图表显示的数据（采样后）
  bool _isLoading = false;
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _endTime = TimeOfDay.now();
  
  int _sensorCount = 3;
  
  // 图表控制
  double _minY = 0;
  double _maxY = 100;
  
  // 固定显示100个数据点
  static const int _chartPointCount = 100;
  
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _timeFormat = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  void _loadPatients() {
    setState(() {
      _patients = SessionService.getPatients();
    });
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  void _setQuickRange(int hours) {
    final now = DateTime.now();
    setState(() {
      _endDate = now;
      _endTime = TimeOfDay(hour: now.hour, minute: now.minute);
      
      final start = now.subtract(Duration(hours: hours));
      _startDate = start;
      _startTime = TimeOfDay(hour: start.hour, minute: start.minute);
    });
    _fetchData();
  }

  String _formatDateTime(DateTime date, TimeOfDay time) {
    return '${_dateFormat.format(date)} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
  }

  Future<void> _fetchData() async {
    if (_selectedPatient == null) return;

    setState(() => _isLoading = true);

    final response = await SensorApiService.getSensorDataByTimeRange(
      patient: _selectedPatient!,
      startTime: _formatDateTime(_startDate, _startTime),
      endTime: _formatDateTime(_endDate, _endTime),
      sensorType: _selectedSensor,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (response.status == 'success') {
          _dataList = response.data;
          _processChartData();
        } else {
          _dataList = [];
          _chartData = [];
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
      _chartData = List.from(_dataList);
    } else {
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
        title: const Text('历史数据'),
        actions: [
          if (_selectedPatient != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchData,
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

            // 时间选择卡片
            _buildTimeRangeCard(),
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

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
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
                        if (value != null) {
                          final patient = _patients.firstWhere((p) => p.name == value);
                          _sensorCount = patient.sensorCount;
                        }
                      });
                      if (value != null) {
                        _fetchData();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
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
                          _fetchData();
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '时间范围',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // 快捷按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _setQuickRange(24),
                    child: const Text('24小时'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _setQuickRange(24 * 7),
                    child: const Text('1周'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _setQuickRange(24 * 30),
                    child: const Text('1月'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 开始时间
            Row(
              children: [
                const Text('开始：'),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _selectStartDate,
                    child: Text(_dateFormat.format(_startDate)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _selectStartTime,
                    child: Text(_startTime.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 结束时间
            Row(
              children: [
                const Text('结束：'),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _selectEndDate,
                    child: Text(_dateFormat.format(_endDate)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _selectEndTime,
                    child: Text(_endTime.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 查询按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedPatient == null || _isLoading
                    ? null
                    : _fetchData,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('查询数据'),
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
              '数据图表',
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
                  ? _buildEmptyState('请选择患者', '选择患者后将显示数据图表')
                  : _chartData.isEmpty
                      ? _buildEmptyState('暂无数据', '请调整时间范围后查询')
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

    return InteractiveViewer(
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
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[400]),
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
    
    // 显示最近的数据，最多显示20条
    final displayData = _dataList.length > 20 
        ? _dataList.sublist(_dataList.length - 20) 
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
                Text(
                  '详细数据 (共 ${_dataList.length} 条)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
