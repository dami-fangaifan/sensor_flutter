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
  bool _isLoading = false;
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay _endTime = TimeOfDay.now();
  
  int _sensorCount = 3;
  
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
        } else {
          _dataList = [];
        }
      });
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
            const SizedBox(height: 12),
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
          bottomTitles: AxisAxes(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < _dataList.length) {
                  // 每隔一定间隔显示一个标签
                  final interval = (_dataList.length / 5).floor().max(1);
                  if (index % interval == 0) {
                    return Text(
                      _dataList[index].formattedTime.substring(0, 5),
                      style: const TextStyle(fontSize: 8),
                    );
                  }
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

extension on int {
  int get max => this;
}
