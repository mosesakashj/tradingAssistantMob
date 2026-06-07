import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class MarginGauge extends StatelessWidget {
  const MarginGauge({
    super.key,
    required this.marginLevelPct,
    this.size = 180,
  });

  final double marginLevelPct;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Clamp to 0-500% for display; infinity = full green gauge
    final clamped = marginLevelPct == double.infinity
        ? 500.0
        : marginLevelPct.clamp(0.0, 500.0);

    final fillFraction = clamped / 500.0;
    final gaugeColor = AppTheme.marginLevelColor(marginLevelPct);

    return SizedBox(
      width: size,
      height: size * 0.6,
      child: CustomPaint(
        painter: _GaugePainter(
          fillFraction: fillFraction,
          fillColor: gaugeColor,
          backgroundColor: const Color(0xFF2A2A4A),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.fillFraction,
    required this.fillColor,
    required this.backgroundColor,
  });

  final double fillFraction;
  final Color fillColor;
  final Color backgroundColor;

  // The arc spans from 180° to 0° (bottom half circle, opening upward)
  static const _startAngle = pi;     // 180°
  static const _sweepTotal = -pi;    // sweeps to 0°

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height;
    final radius = size.width / 2 - 8;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    // Background track
    canvas.drawArc(rect, _startAngle, _sweepTotal, false, bgPaint);

    // Filled arc
    final sweepAngle = _sweepTotal * fillFraction;
    canvas.drawArc(rect, _startAngle, sweepAngle, false, fgPaint);

    // Needle
    final needleAngle = _startAngle + sweepAngle;
    final nx = cx + (radius) * cos(needleAngle);
    final ny = cy + (radius) * sin(needleAngle);

    final needlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(cx, cy),
      Offset(nx, ny),
      needlePaint,
    );

    // Centre dot
    canvas.drawCircle(
      Offset(cx, cy),
      5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.fillFraction != fillFraction || old.fillColor != fillColor;
}
