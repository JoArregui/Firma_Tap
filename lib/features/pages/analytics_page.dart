import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/storage/history_service.dart';

/// Dashboard de analítica de firmas.
/// - BarChart: firmas por día últimos 7 días
/// - PieChart: distribución por tipoDocumento
/// - LineChart: evolución diaria (totales)
/// Lee datos de [HistoryService.getAll()].
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool _loading = true;
  List<HistorialEntry> _entries = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final all = await HistoryService.getAll();
      debugPrint('[AnalyticsPage] Cargados ${all.length} registros');
      if (!mounted) return;
      setState(() {
        _entries = all;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('[AnalyticsPage] Error getAll: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Computations
  // ---------------------------------------------------------------------------

  /// Mapa día (yyyy-MM-dd) -> count para últimos 7 días (incluye hoy)
  Map<DateTime, int> _firmasPorDia() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    // Inicializa 7 días a 0
    final Map<DateTime, int> map = {};
    for (int i = 0; i < 7; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      // Normaliza con DateTime para manejar saltos de mes
      final key = DateTime(d.year, d.month, d.day);
      map[key] = 0;
    }
    for (final e in _entries) {
      final day = DateTime(e.fecha.year, e.fecha.month, e.fecha.day);
      if (map.containsKey(day)) {
        map[day] = map[day]! + 1;
      }
    }
    // Re-normalizar claves por si hubo overflow de day
    final normalized = <DateTime, int>{};
    for (final k in map.keys) {
      final nk = DateTime(k.year, k.month, k.day);
      normalized[nk] = map[k]!;
    }
    // Ordena por fecha asc
    final sortedKeys = normalized.keys.toList()..sort();
    return {for (final k in sortedKeys) k: normalized[k]!};
  }

  Map<String, int> _porTipoDocumento() {
    final m = <String, int>{};
    for (final e in _entries) {
      final tipo = e.tipoDocumento.isEmpty ? 'Desconocido' : e.tipoDocumento;
      m[tipo] = (m[tipo] ?? 0) + 1;
    }
    return m;
  }

  String _fmtDay(DateTime d) => '${d.day}/${d.month}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analítica de Firmas'),
        backgroundColor: const Color.fromARGB(255, 0, 47, 108),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text('Error: $_error', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : _entries.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bar_chart, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text('Sin datos aún', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text('Las firmas registradas aparecerán aquí',
                                style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSummaryCard(),
                            const SizedBox(height: 16),
                            _buildBarChartCard(),
                            const SizedBox(height: 16),
                            _buildPieChartCard(),
                            const SizedBox(height: 16),
                            _buildLineChartCard(),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildSummaryCard() {
    final porTipo = _porTipoDocumento();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _summaryItem('Total', _entries.length.toString(), Icons.description, const Color.fromARGB(255, 0, 47, 108)),
            _summaryItem('Tipos', porTipo.length.toString(), Icons.category, Colors.orange),
            _summaryItem('Últimos 7d', _firmasPorDia().values.fold<int>(0, (a, b) => a + b).toString(), Icons.calendar_today, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildBarChartCard() {
    final perDay = _firmasPorDia();
    final keys = perDay.keys.toList();
    final values = perDay.values.toList();
    final maxY = (values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b)).toDouble();
    final yMax = (maxY < 5 ? 5 : maxY + 1).toDouble();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Firmas por día (últimos 7 días)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: yMax,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= keys.length) return const SizedBox.shrink();
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(_fmtDay(keys[idx]), style: const TextStyle(fontSize: 11)),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(value.toInt().toString(), style: const TextStyle(fontSize: 11)),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(keys.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: values[i].toDouble(),
                          color: const Color.fromARGB(255, 0, 47, 108),
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartCard() {
    final porTipo = _porTipoDocumento();
    if (porTipo.isEmpty) return const SizedBox.shrink();
    final total = porTipo.values.fold<int>(0, (a, b) => a + b);
    final colors = [const Color(0xFF002F6C), Colors.orange, Colors.green, Colors.redAccent, Colors.purple, Colors.teal, Colors.amber];
    final entries = porTipo.entries.toList();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Distribución por tipo de documento',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: List.generate(entries.length, (i) {
                    final e = entries[i];
                    final pct = total == 0 ? 0 : (e.value / total * 100);
                    return PieChartSectionData(
                      value: e.value.toDouble(),
                      color: colors[i % colors.length],
                      title: '${pct.toStringAsFixed(1)}%',
                      radius: 70,
                      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: List.generate(entries.length, (i) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('${entries[i].key} (${entries[i].value})', style: const TextStyle(fontSize: 12)),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChartCard() {
    final perDay = _firmasPorDia();
    final keys = perDay.keys.toList();
    final values = perDay.values.toList();
    if (keys.isEmpty) return const SizedBox.shrink();
    final maxY = values.reduce((a, b) => a > b ? a : b).toDouble();
    final yMax = (maxY < 5 ? 5 : maxY + 1).toDouble();
    final spots = List.generate(keys.length, (i) => FlSpot(i.toDouble(), values[i].toDouble()));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Evolución diaria (totales)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (keys.length - 1).toDouble(),
                  minY: 0,
                  maxY: yMax,
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= keys.length) return const SizedBox.shrink();
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(_fmtDay(keys[idx]), style: const TextStyle(fontSize: 11)),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(value.toInt().toString(), style: const TextStyle(fontSize: 11)),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: const Color.fromARGB(255, 0, 47, 108),
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color.fromARGB(255, 0, 47, 108).withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
