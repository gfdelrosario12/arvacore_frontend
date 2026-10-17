import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class SimulatedTelemetryChart extends StatelessWidget {
  final List<double> dataPoints;
  final Color lineColor;
  final Color? fillColor;
  final String? labelSuffix;

  const SimulatedTelemetryChart({
    super.key,
    required this.dataPoints,
    this.lineColor = AppColors.primary,
    this.fillColor,
    this.labelSuffix = '%',
  });

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty || (dataPoints.length == 1 && dataPoints.first == 0.0)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart, size: 28, color: Colors.grey.withValues(alpha: 0.5)),
              const SizedBox(height: 6),
              Text(
                'Awaiting Sensor Telemetry History',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final effectiveFill = fillColor ?? lineColor.withValues(alpha: 0.15);

    return CustomPaint(
      painter: _ChartPainter(
        dataPoints: dataPoints,
        lineColor: lineColor,
        fillColor: effectiveFill,
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final Color lineColor;
  final Color fillColor;

  _ChartPainter({
    required this.dataPoints,
    required this.lineColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final path = Path();
    final fillPath = Path();

    final minVal = dataPoints.reduce((a, b) => a < b ? a : b);
    final maxVal = dataPoints.reduce((a, b) => a > b ? a : b);
    final range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    final dx = size.width / (dataPoints.length - 1);

    for (int i = 0; i < dataPoints.length; i++) {
      final x = i * dx;
      final normalized = (dataPoints[i] - minVal) / range;
      final y = size.height - (normalized * (size.height - 20)) - 10;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < dataPoints.length; i++) {
      final x = i * dx;
      final normalized = (dataPoints[i] - minVal) / range;
      final y = size.height - (normalized * (size.height - 20)) - 10;
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) => true;
}
