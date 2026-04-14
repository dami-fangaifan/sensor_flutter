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
  List<DataModel> _displayData = [];
  bool _isLoading = false;
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _endTime = TimeOfDay.now();
  
  int _sensorCount = 3;
  
  // 图表控制
  final int _maxDisplayPoints = 100;
  int _displayPointCount = 50;
  double _minY = 0;
  double _maxY = 100;
  double _chartOffset = 0; // 滑动偏移
  
  // 统计数据
  double _avgValue = 0;
  double _maxValue = 0;
  double _minValue = 0;
  int _dataPointCount = 0;
  
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
          _dataPointCount = _dataList.length;
          _chartOffset = 0;
          _calculateStatistics();
          _updateDisplayData();
        } else {
          _dataList = [];
          _displayData = [];
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
    
    _minY = (_minValue - 5).clamp(0, double.infinity);
    _maxY = _maxValue + 5;
  }
  
  void _updateDisplayData() {
    if (_dataList.isEmpty) {
      _displayData = [];
      return;
    }
    
    if (_dataList.length <= _displayPointCount) {
      _displayData = _dataList;
    } else {
      final startIdx = _chartOffset.toInt();
      var endIdx = startIdx + _displayPointCount;
      if (endIdx > _dataList.length) {
        endIdx = _dataList.length;
      }
      _displayData = _dataList.sublist(startIdx, endIdx);
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
                        _displayData = [];
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '数据图表',
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
                      '共 $_dataPointCount 个数据点',
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
                        min: 20,
                        max: _maxDisplayPoints.toDouble(),
                        divisions: 4,
                        label: '$_displayPointCount',
                        onChanged: (value) {
                          setState(() {
                            _displayPointCount = value.toInt();
                            _updateDisplayData();
                          });
                        },
                      ),
                    ),
                    Text('$_displayPointCount', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              
            // 滑动控制（当数据量大时）
            if (_dataList.length > _displayPointCount)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _chartOffset > 0
                          ? () {
                              setState(() {
                                _chartOffset = max(0, _chartOffset - _displayPointCount / 2);
                                _updateDisplayData();
                              });
                            }
                          : null,
                    ),
                    Expanded(
                      child: Text(
                        '显示 ${_chartOffset.toInt() + 1} - ${min(_chartOffset.toInt() + _displayPointCount, _dataList.length)} 条',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _chartOffset + _displayPointCount < _dataList.length
                          ? () {
                              setState(() {
                                _chartOffset = min(
                                  _dataList.length - _displayPointCount.toDouble(),
                                  _chartOffset + _displayPointCount / 2,
                                );
                                _updateDisplayData();
                              });
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            
            SizedBox(
              height: 280,
              child: _selectedPatient == null
                  ? _buildEmptyState('请选择患者', '选择患者后将显示数据图表')
                  : _dataList.isEmpty
                      ? _buildEmptyState('暂无数据', '请调整时间范围后查询')
                      : _buildLineChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    final spots = _displayData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value);
    }).toList();

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        
        if (details.primaryVelocity! > 0 && _chartOffset > 0) {
          // 向右滑动 - 显示更早的数据
          setState(() {
            _chartOffset = max(0, _chartOffset - _displayPointCount / 3);
            _updateDisplayData();
          });
        } else if (details.primaryVelocity! < 0 && _chartOffset + _displayPointCount < _dataList.length) {
          // 向左滑动 - 显示更新的数据
          setState(() {
            _chartOffset = min(
              _dataList.length - _displayPointCount.toDouble(),
              _chartOffset + _displayPointCount / 3,
            );
            _updateDisplayData();
          });
        }
      },
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            verticalInterval: max(1, _displayData.length / 5),
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
                interval: max(1, _displayData.length / 5),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < _displayData.length) {
                    final showLabel = index == 0 || 
                        index == _displayData.length - 1 ||
                        index % max(1, (_displayData.length / 5).floor()) == 0;
                    if (showLabel) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _displayData[index].formattedTime.substring(0, 5),
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
          maxX: (_displayData.length - 1).toDouble().clamp(0, double.infinity),
          minY: _minY,
          maxY: _maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF5E9ED6),
              barWidth: 2.5,
              dotData: FlDotData(
                show: _displayData.length <= 30,
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
                  if (index >= 0 && index < _displayData.length) {
                    final data = _displayData[index];
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
              child: Column(
                children: [
                  Row(
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.grey[600], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '查询时间范围: ${_dateFormat.format(_startDate)} ${_startTime.format(context)} - ${_dateFormat.format(_endDate)} ${_endTime.format(context)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ),
                    ],
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
