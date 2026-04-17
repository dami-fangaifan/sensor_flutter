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
  List<DataModel> _chartData = [];
  bool _isLoading = false;
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _endTime = TimeOfDay.now();
  
  int _sensorCount = 3;
  double _minY = 0;
  double _maxY = 100;
  
  // 图表缩放状态
  double _chartScale = 1.0;  // 当前缩放比例
  static const double _minScale = 0.5;   // 最小缩放（缩小）
  static const double _maxScale = 3.0;   // 最大缩放（放大）
  static const int _minPoints = 10;      // 最小点数（放大时）
  static const int _maxPoints = 100;     // 最大点数（缩小时）
  static const int _chartDisplayPoints = 50;  // 图表显示点数（与Android一致）
  
  // 第一级采样后的数据（用于详细数据列表）
  List<DataModel> _firstLevelData = [];
  
  int? _selectedQuickRange;
  
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _timeFormat = DateFormat('HH:mm');
  final _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _setQuickRange(24 * 7, 1); // 默认显示1周数据
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
      setState(() {
        _startDate = picked;
        _selectedQuickRange = null;
      });
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
      setState(() {
        _endDate = picked;
        _selectedQuickRange = null;
      });
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        _selectedQuickRange = null;
      });
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
        _selectedQuickRange = null;
      });
    }
  }

  void _setQuickRange(int hours, int index) {
    final now = DateTime.now();
    setState(() {
      _endDate = now;
      _endTime = TimeOfDay(hour: now.hour, minute: now.minute);
      final start = now.subtract(Duration(hours: hours));
      _startDate = start;
      _startTime = TimeOfDay(hour: start.hour, minute: start.minute);
      _selectedQuickRange = index;
      // 重置缩放
      _chartScale = 1.0;
    });
    // 自动获取数据
    if (_selectedPatient != null) {
      _fetchData();
    }
  }

  String _formatDateTime(DateTime date, TimeOfDay time) {
    return '${_dateFormat.format(date)} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
  }

  Future<void> _fetchData() async {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择患者')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _chartData = [];
      _dataList = [];
      _firstLevelData = []; // 清空第一级采样数据
      _chartScale = 1.0; // 重置缩放
    });

    try {
      final response = await SensorApiService.getSensorDataByTimeRange(
        patient: _selectedPatient!,
        startTime: _formatDateTime(_startDate, _startTime),
        endTime: _formatDateTime(_endDate, _endTime),
        sensorType: _selectedSensor,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response.status == 'success' && response.data.isNotEmpty) {
            // 按时间排序
            _dataList = response.data.toList()
              ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
            _processChartData();
          } else {
            _dataList = [];
            _chartData = [];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _dataList = [];
          _chartData = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取数据失败: $e')),
        );
      }
    }
  }
  
  /// 双级采样处理数据（参考Android实现）
  /// 第一级：API数据 -> 最多100点（用于详细数据列表）
  /// 第二级：图表显示 -> 根据缩放动态计算点数，使用平均值
  void _processChartData() {
    if (_dataList.isEmpty) {
      _chartData = [];
      _firstLevelData = [];
      return;
    }
    
    // 第一级采样：最多100点（用于详细列表）
    _firstLevelData = _dataList.length <= _maxPoints 
        ? List.from(_dataList)
        : _sampleDataAverage(_dataList, _maxPoints);
    
    // 第二级采样：根据缩放计算显示点数，使用平均值
    final pointCount = _calculatePointCount(_chartScale);
    if (_firstLevelData.length <= pointCount) {
      _chartData = List.from(_firstLevelData);
    } else {
      _chartData = _sampleDataAverage(_firstLevelData, pointCount);
    }
    
    // 计算Y轴范围
    _updateYAxisRange();
  }
  
  /// 根据缩放比例计算显示点数
  /// 放大(scale↑) → 点数↓ → 显示更精细的时间段
  /// 缩小(scale↓) → 点数↑ → 显示更全面的时间段
  int _calculatePointCount(double scale) {
    // 线性映射: scale [1.0, 3.0] → points [100, 10]
    // scale = 1.0 → 100点
    // scale = 2.0 → 55点
    // scale = 3.0 → 10点
    final normalizedScale = (scale - 1.0) / (_maxScale - 1.0); // 0.0 ~ 1.0
    final pointCount = (_maxPoints - normalizedScale * (_maxPoints - _minPoints)).round();
    return pointCount.clamp(_minPoints, _maxPoints);
  }
  
  void _updateYAxisRange() {
    if (_chartData.isEmpty) return;
    
    final values = _chartData.map((d) => d.value).toList();
    final minVal = values.reduce(min);
    final maxVal = values.reduce(max);
    
    // 确保Y轴范围合理
    final padding = max(5.0, (maxVal - minVal) * 0.1);
    _minY = (minVal - padding).clamp(0.0, double.infinity);
    _maxY = maxVal + padding;
    
    // 如果范围太小，扩展到至少10
    if (_maxY - _minY < 10) {
      final mid = (_maxY + _minY) / 2;
      _minY = (mid - 5).clamp(0.0, double.infinity);
      _maxY = mid + 5;
    }
  }
  
  /// 平均值采样数据（参考Android实现）
  /// 将数据分成targetCount个区间，每个区间取平均值
  List<DataModel> _sampleDataAverage(List<DataModel> data, int targetCount) {
    if (data.length <= targetCount) return data;
    
    final result = <DataModel>[];
    final step = data.length / targetCount;
    
    for (int i = 0; i < targetCount; i++) {
      final startIndex = (i * step).floor();
      final endIndex = min(((i + 1) * step).floor(), data.length);
      
      // 取区间内的平均值（参考Android实现）
      final sublist = data.sublist(startIndex, endIndex);
      final avgValue = sublist.map((d) => d.value).reduce((a, b) => a + b) / sublist.length;
      
      // 使用区间的第一个时间戳
      result.add(DataModel(
        timestamp: data[startIndex].timestamp,
        value: avgValue,
        patient: data[startIndex].patient,
      ));
    }
    return result;
  }
  
  String _getStatusText(double value) {
    if (value > 15) return '高风险';
    if (value > 10) return '偏高';
    return '正常';
  }
  
  Color _getStatusColor(double value) {
    if (value > 15) return Colors.red;
    if (value > 10) return Colors.orange;
    return Colors.green;
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
              onPressed: _isLoading ? null : _fetchData,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPatientCard(),
              const SizedBox(height: 12),
              _buildTimeRangeCard(),
              const SizedBox(height: 12),
              _buildChartCard(),
              const SizedBox(height: 12),
              _buildAnalysisCard(),
              const SizedBox(height: 12),
              if (_firstLevelData.isNotEmpty) _buildDetailDataCard(),
            ],
          ),
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
            const Text('患者信息', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                      ..._patients.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name))),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedPatient = value;
                        _dataList = [];
                        _chartData = [];
                        _firstLevelData = []; // 清空第一级采样数据
                        _chartScale = 1.0;
                        if (value != null) {
                          final patient = _patients.firstWhere((p) => p.name == value);
                          _sensorCount = patient.sensorCount;
                        }
                      });
                      if (value != null) _fetchData();
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
                    items: List.generate(_sensorCount, (i) => DropdownMenuItem(
                      value: 'sensor${i + 1}',
                      child: Text('传感器 ${i + 1}'),
                    )),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedSensor = value);
                        if (_selectedPatient != null) _fetchData();
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('时间范围', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_dateFormat.format(_startDate)} ${_startTime.format(context)} - ${_dateFormat.format(_endDate)} ${_endTime.format(context)}',
                    style: TextStyle(fontSize: 10, color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildQuickButton('24小时', 0, () => _setQuickRange(24, 0))),
                const SizedBox(width: 8),
                Expanded(child: _buildQuickButton('1周', 1, () => _setQuickRange(24 * 7, 1))),
                const SizedBox(width: 8),
                Expanded(child: _buildQuickButton('1月', 2, () => _setQuickRange(24 * 30, 2))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('开始：'),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _selectStartDate,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _selectedQuickRange == null ? Colors.blue[50] : null,
                    ),
                    child: Text(_dateFormat.format(_startDate)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _selectStartTime,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _selectedQuickRange == null ? Colors.blue[50] : null,
                    ),
                    child: Text(_startTime.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('结束：'),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _selectEndDate,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _selectedQuickRange == null ? Colors.blue[50] : null,
                    ),
                    child: Text(_dateFormat.format(_endDate)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _selectEndTime,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _selectedQuickRange == null ? Colors.blue[50] : null,
                    ),
                    child: Text(_endTime.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedPatient == null || _isLoading ? null : _fetchData,
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
                    : const Text('查询数据'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuickButton(String label, int index, VoidCallback onPressed) {
    final isSelected = _selectedQuickRange == index;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF5E9ED6) : null,
        foregroundColor: isSelected ? Colors.white : const Color(0xFF5E9ED6),
        side: BorderSide(color: const Color(0xFF5E9ED6)),
      ),
      child: Text(label),
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
                const Text('数据图表', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (_chartData.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '显示 ${_chartData.length} / ${_firstLevelData.length} 点', 
                      style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '双指缩放：外张→放大→细节 | 内捏→缩小→概览',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 280,
              child: _selectedPatient == null
                  ? _buildEmptyState('请选择患者', '选择患者后将显示数据图表')
                  : _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _chartData.isEmpty
                          ? _buildEmptyState('暂无数据', '请调整时间范围后点击"查询数据"')
                          : _buildLineChart(),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建可缩放的折线图（使用GestureDetector检测双指缩放）
  Widget _buildLineChart() {
    // 生成数据点
    final spots = <FlSpot>[];
    for (int i = 0; i < _chartData.length; i++) {
      spots.add(FlSpot(i.toDouble(), _chartData[i].value));
    }

    return GestureDetector(
      onScaleStart: (details) {
        // 记录初始缩放
      },
      onScaleUpdate: (details) {
        // 使用 pointers 判断是否是双指手势
        if (details.pointerCount >= 2) {
          final newScale = details.scale.clamp(_minScale, _maxScale);
          if ((newScale - _chartScale).abs() > 0.05) {
            _chartScale = newScale;
            if (_firstLevelData.isNotEmpty) {
              final pointCount = _calculatePointCount(_chartScale);
              if (_firstLevelData.length <= pointCount) {
                _chartData = List.from(_firstLevelData);
              } else {
                _chartData = _sampleDataAverage(_firstLevelData, pointCount);
              }
              _updateYAxisRange();
              setState(() {});
            }
          }
        }
      },
      onScaleEnd: (details) {
        // 缩放结束
      },
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            verticalInterval: max(1, _chartData.length / 8),
            horizontalInterval: max(1, (_maxY - _minY) / 6),
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[300]!, strokeWidth: 1),
            getDrawingVerticalLine: (value) => FlLine(color: Colors.grey[200]!, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) => Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                interval: max(1, _chartData.length / 5),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < _chartData.length) {
                    final time = _chartData[index].formattedTime;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        time.substring(0, min(5, time.length)),
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey[300]!),
          ),
          minX: 0,
          maxX: (_chartData.length - 1).toDouble().clamp(0, double.infinity),
          minY: _minY,
          maxY: _maxY,
          clipData: FlClipData.all(),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              // 贝塞尔曲线平滑（参考Android CUBIC_BEZIER）
              isCurved: true,
              curveSmoothness: 0.15, // 与Android cubicIntensity一致
              color: const Color(0xFF5E9ED6),
              barWidth: 2.5,
              dotData: FlDotData(
                show: _chartData.length <= 30,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: const Color(0xFF5E9ED6),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF5E9ED6).withOpacity(0.3),
                    const Color(0xFFB3D9F2).withOpacity(0.1),
                  ],
                ),
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
            const Text('数据分析', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                  Text('正在开发中...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text('更多数据分析功能即将上线', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailDataCard() {
    // 使用第一级采样数据（最多100点）显示详细列表
    final displayData = _firstLevelData.length > 20 
        ? _firstLevelData.sublist(_firstLevelData.length - 20) 
        : _firstLevelData;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('详细数据 (共 ${_firstLevelData.length} 条)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('时间', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey))),
                  Expanded(flex: 1, child: Text('压力值', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey))),
                  Expanded(flex: 1, child: Text('状态', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey))),
                ],
              ),
            ),
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
        border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(data.formattedTime, style: const TextStyle(fontSize: 12))),
          Expanded(flex: 1, child: Text(data.value.toStringAsFixed(2), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (statusText == '高风险') const Icon(Icons.warning, color: Colors.red, size: 14),
                Text(statusText, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
