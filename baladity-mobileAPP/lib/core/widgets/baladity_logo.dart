import 'package:flutter/material.dart';

class BaladityLogo extends StatelessWidget {
  const BaladityLogo({
    super.key,
    this.height = 48,
    this.showBackground = false,
  });

  final double height;
  final bool showBackground;

  static const Color _green = Color(0xFF00D46A);
  static const Color _dark = Color(0xFF050B12);
  static const String _darkAssetPath = 'assets/images/baladity_logo.png';
  static const String _lightAssetPath = 'assets/images/baladity_logo_light.png';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final logo = Image.asset(
      isDark ? _darkAssetPath : _lightAssetPath,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => _FallbackBaladityLogo(height: height),
    );

    if (!showBackground) return logo;

    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: height * 0.24),
      decoration: BoxDecoration(
        color: _dark,
        borderRadius: BorderRadius.circular(height * 0.16),
      ),
      child: Center(child: logo),
    );
  }
}

class _FallbackBaladityLogo extends StatelessWidget {
  const _FallbackBaladityLogo({required this.height});

  final double height;

  static const Color _green = Color(0xFF00D46A);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'بلديتي',
            style: TextStyle(
              color: _green,
              fontSize: height * 0.5,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          SizedBox(width: height * 0.12),
          SizedBox(
            width: height * 0.78,
            height: height * 0.78,
            child: CustomPaint(painter: _BaladityMarkPainter()),
          ),
        ],
      ),
    );
  }
}

class _BaladityMarkPainter extends CustomPainter {
  static const Color _green = Color(0xFF00D46A);
  static const Color _white = Color(0xFFEFF6F1);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.065;
    final whitePaint = Paint()
      ..color = _white
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final greenPaint = Paint()
      ..color = _green
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final building = Path()
      ..moveTo(size.width * 0.18, size.height * 0.72)
      ..lineTo(size.width * 0.18, size.height * 0.48)
      ..lineTo(size.width * 0.32, size.height * 0.38)
      ..lineTo(size.width * 0.46, size.height * 0.48)
      ..lineTo(size.width * 0.46, size.height * 0.72)
      ..moveTo(size.width * 0.32, size.height * 0.72)
      ..lineTo(size.width * 0.32, size.height * 0.18)
      ..lineTo(size.width * 0.55, size.height * 0.28)
      ..lineTo(size.width * 0.55, size.height * 0.72);
    canvas.drawPath(building, whitePaint);

    final arch = Path()
      ..moveTo(size.width * 0.05, size.height * 0.76)
      ..cubicTo(
        size.width * 0.16,
        size.height * 0.15,
        size.width * 0.75,
        size.height * 0.12,
        size.width * 0.82,
        size.height * 0.58,
      );
    canvas.drawPath(arch, whitePaint);

    final branch = Path()
      ..moveTo(size.width * 0.55, size.height * 0.78)
      ..cubicTo(
        size.width * 0.68,
        size.height * 0.66,
        size.width * 0.82,
        size.height * 0.48,
        size.width,
        size.height * 0.18,
      );
    canvas.drawPath(branch, greenPaint);

    for (final leaf in const [
      Offset(0.66, 0.67),
      Offset(0.75, 0.56),
      Offset(0.84, 0.43),
      Offset(0.9, 0.3),
    ]) {
      final center = Offset(size.width * leaf.dx, size.height * leaf.dy);
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: size.width * 0.18,
          height: size.height * 0.1,
        ),
        Paint()..color = _green,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
