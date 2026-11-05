import 'package:flutter/material.dart';

class KosMateLogo extends StatelessWidget {
  final double size;
  final Color color;

  const KosMateLogo({
    super.key,
    this.size = 32.0,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * (300 / 320),
      child: CustomPaint(
        painter: _KosMateLogoPainter(color: color),
      ),
    );
  }
}

class _KosMateLogoPainter extends CustomPainter {
  final Color color;

  _KosMateLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 320.0;

    final roofPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 32.0 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 32.0 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final doorPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28.0 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Path 1: Roof (M16 144 L160 16 L304 144)
    final roofPath = Path()
      ..moveTo(16.0 * scale, 144.0 * scale)
      ..lineTo(160.0 * scale, 16.0 * scale)
      ..lineTo(304.0 * scale, 144.0 * scale);
    canvas.drawPath(roofPath, roofPaint);

    // Path 2: Body (M48 128 V284 H272 V128)
    final bodyPath = Path()
      ..moveTo(48.0 * scale, 128.0 * scale)
      ..lineTo(48.0 * scale, 284.0 * scale)
      ..lineTo(272.0 * scale, 284.0 * scale)
      ..lineTo(272.0 * scale, 128.0 * scale);
    canvas.drawPath(bodyPath, bodyPaint);

    // Path 3: Door (M128 284 V202 C128 186 136 178 152 178 H168 C184 178 192 186 192 202 V284)
    final doorPath = Path()
      ..moveTo(128.0 * scale, 284.0 * scale)
      ..lineTo(128.0 * scale, 202.0 * scale)
      ..cubicTo(
        128.0 * scale,
        186.0 * scale,
        136.0 * scale,
        178.0 * scale,
        152.0 * scale,
        178.0 * scale,
      )
      ..lineTo(168.0 * scale, 178.0 * scale)
      ..cubicTo(
        184.0 * scale,
        178.0 * scale,
        192.0 * scale,
        186.0 * scale,
        192.0 * scale,
        202.0 * scale,
      )
      ..lineTo(192.0 * scale, 284.0 * scale);
    canvas.drawPath(doorPath, doorPaint);
  }

  @override
  bool shouldRepaint(covariant _KosMateLogoPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

