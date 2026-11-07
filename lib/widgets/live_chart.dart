import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/biometric_reading.dart';
import '../theme/app_theme.dart';

/// Gráfica en tiempo real de las últimas lecturas.
class LiveChart extends StatelessWidget {
  final String title;
  final List<BiometricReading> data;
  final double Function(BiometricReading) pick;
  final double minY;
  final double maxY;
  final String unit;

  const LiveChart({
    super.key,
    required this.title,
    required this.data,
    required this.pick,
    required this.minY,
    required this.maxY,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (var i = 0; i < data.length; i++) FlSpot(i.toDouble(), pick(data[i])),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.blue100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '$title ($unit)',
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: spots.length < 2
                ? const Center(
                    child: Text(
                      'Esperando lecturas…',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : LineChart(
                    duration: Duration.zero,
                    LineChartData(
                      minY: minY,
                      maxY: maxY,
                      minX: spots.first.x,
                      maxX: spots.last.x,
                      lineTouchData: const LineTouchData(enabled: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        bottomTitles: const AxisTitles(),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 38,
                            getTitlesWidget: (v, meta) {
                              if (v == meta.min || v == meta.max) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                v.toStringAsFixed(unit == '°C' ? 1 : 0),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => const FlLine(
                          color: AppColors.blue100,
                          strokeWidth: 1,
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.25,
                          color: AppColors.blue700,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.blue500.withValues(alpha: 0.30),
                                AppColors.blue500.withValues(alpha: 0.02),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
