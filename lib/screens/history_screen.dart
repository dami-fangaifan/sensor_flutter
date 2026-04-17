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
  
  // 采样配置
  static const int _minDisplayPoints = 20;  // 最小显示点数
  static const int _maxDisplayPoints = 100; // 最大显示点数
  int _displayPointCount = 100;             // 当前显示点数
  
  // 第一级采样后的数据（用于详细数据列表）
  List<DataModel> _firstLevelData = [];
  
  // 选中的数据点索引（用于显示时间戳）
  int? _selectedPointIndex;
  
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
  
  /// 采样处理数据（参考Android实现）
  void _processChartData() {
    if (_dataList.isEmpty) {
      _chartData = [];
      _firstLevelData = [];
      return;
    }
    
    // 第一级采样：最多100点（基于原始数据）
    _firstLevelData = _dataList.length <= _maxDisplayPoints 
        ? List.from(_dataList)
        : _sampleDataAverage(_dataList, _maxDisplayPoints);
    
    // 第二级采样：根据用户选择的点数，在整个数据范围内取平均
    if (_firstLevelData.length <= _displayPointCount) {
      _chartData = List.from(_firstLevelData);
    } else {
      _chartData = _sampleDataAverage(_firstLevelData, _displayPointCount);
    }
    
    // 计算Y轴范围（基于第一级数据，保持稳定）
    _updateYAxisRange();
  }
  
  void _updateYAxisRange() {
    // 使用第一级数据计算Y轴范围，这样点数变化时纵轴保持稳定
    if (_firstLevelData.isEmpty) return;
    
    final values = _firstLevelData.map((d) => d.value).toList();
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
                        _selectedPointIndex = null; // 清空选中状态
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
                      '显示 ${_chartData.length} 点', 
                      style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // 点数滑动选择器
            Row(
              children: [
                Text('点数: ', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Expanded(
                  child: Slider(
                    value: _displayPointCount.toDouble(),
                    min: _minDisplayPoints.toDouble(),
                    max: _maxDisplayPoints.toDouble(),
                    divisions: 16, // 20-100，每5个一档
                    label: '$_displayPointCount',
                    onChanged: (value) {
                      setState(() {
                        _displayPointCount = value.round();
                        _selectedPointIndex = null;
                      });
                      if (_firstLevelData.isNotEmpty) {
                        _processChartData();
                      }
                    },
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text('$_displayPointCount', 
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[700]),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
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

  /// 构建可横向滚动的折线图（纵轴固定）
  Widget _buildLineChart() {
    // 生成数据点
    final spots = <FlSpot>[];
    for (int i = 0; i < _chartData.length; i++) {
      spots.add(FlSpot(i.toDouble(), _chartData[i].value));
    }
    
    // 计算图表宽度：每个点15像素，最少占满屏幕
    final chartWidth = max(300.0, _chartData.length * 15.0);

    return Row(
      children: [
        // 固定的Y轴区域
        SizedBox(
          width: 50,
          height: 250,
          child: _buildYAxisLabels(),
        ),
        // 可滚动的图表内容
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: chartWidth,
              height: 250,
              child: _buildChartContent(spots, showYAxis: false),
            ),
          ),
        ),
      ],
    );
  }
  
  /// 构建固定的Y轴标签
  Widget _buildYAxisLabels() {
    final interval = max(1, (_maxY - _minY) / 5);
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox(height: 10),
        ...List.generate(5, (index) {
          final value = _maxY - (index + 1) * interval;
          return Text(
            value.toStringAsFixed(1),
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          );
        }),
        const SizedBox(height: 25),
      ],
    );
  }
  
  /// 构建图表内容
  Widget _buildChartContent(List<FlSpot> spots, {bool showYAxis = true}) {
    return LineChart(
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
              showTitles: showYAxis,
              reservedSize: showYAxis ? 50 : 0,
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
            isCurved: true,
            curveSmoothness: 0.15,
            color: const Color(0xFF5E9ED6),
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                // 白色空心点，选中时只改变大小，不改变颜色
                radius: _selectedPointIndex == index ? 5 : 3,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: const Color(0xFF5E9ED6),
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
          touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
            if (event is FlTapUpEvent || event is FlPanDownEvent) {
              if (response != null && response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty) {
                final index = response.lineBarSpots!.first.x.toInt();
                setState(() {
                  // 点击同一个点则取消选中，否则选中新点
                  _selectedPointIndex = _selectedPointIndex == index ? null : index;
                });
              }
            }
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              if (_selectedPointIndex == null) return [];
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                if (index >= 0 && index < _chartData.length && index == _selectedPointIndex) {
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
        extraLinesData: ExtraLinesData(
          extraLinesOnTop: true,
          horizontalLines: [],
          verticalLines: _selectedPointIndex != null && _selectedPointIndex! < _chartData.length
              ? [
                  VerticalLine(
                    x: _selectedPointIndex!.toDouble(),
                    color: const Color(0xFF5E9ED6).withOpacity(0.5),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ]
              : [],
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
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('详细数据 (共 ${_firstLevelData.length} 条)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
            // 可滚动列表显示全部数据
            SizedBox(
              height: 200, // 固定高度
              child: ListView.builder(
                itemCount: _firstLevelData.length,
                itemBuilder: (context, index) {
                  // 倒序显示，最新的在上面
                  final data = _firstLevelData[_firstLevelData.length - 1 - index];
                  return _buildDataRow(data);
                },
              ),
            ),
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
