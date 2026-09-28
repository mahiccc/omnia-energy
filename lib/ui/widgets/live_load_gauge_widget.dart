import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom radial arc gauge displaying total household power load (`P_CT`)
/// segmented into Native (`∑P_Native`), Virtual (`∑P_Virtual`), and
/// Unmonitored Residual (`P_Residual`) power.
class LiveLoadGaugeWidget extends StatelessWidget {
  final double pCtWatts;
  final double pNativeWatts;
  final double pVirtualWatts;
  final double pResidualWatts;
  final double maxGaugeWatts;

  const LiveLoadGaugeWidget({
    super.key,
    required this.pCtWatts,
    required this.pNativeWatts,
    required this.pVirtualWatts,
    required this.pResidualWatts,
    this.maxGaugeWatts = 5000.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141A24),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Text(
            'MAIN CT CLAMP — LIVE HOUSEHOLD LOAD',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 220,
            height: 160,
            child: CustomPaint(
              painter: _RadialLoadGaugePainter(
                pCtWatts: pCtWatts,
                pNativeWatts: pNativeWatts,
                pVirtualWatts: pVirtualWatts,
                pResidualWatts: pResidualWatts,
                maxWatts: maxGaugeWatts,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${pCtWatts.toStringAsFixed(0)} W',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(pCtWatts / 1000.0).toStringAsFixed(2)} kW Total (P_CT)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadialLoadGaugePainter extends CustomPainter {
  final double pCtWatts;
  final double pNativeWatts;
  final double pVirtualWatts;
  final double pResidualWatts;
  final double maxWatts;

  _RadialLoadGaugePainter({
    required this.pCtWatts,
    required this.pNativeWatts,
    required this.pVirtualWatts,
    required this.pResidualWatts,
    required this.maxWatts,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const startAngle = math.pi * 0.8;
    const sweepTotal = math.pi * 1.4;
    final center = Offset(size.width / 2, size.height * 0.65);
    final radius = math.min(size.width, size.height) * 0.58;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = const Color(0xFF232D3F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepTotal, false, trackPaint);

    final safeMax = maxWatts <= 0 ? 5000.0 : maxWatts;
    final totalRatio = (pCtWatts / safeMax).clamp(0.0, 1.0);
    final activeSweep = sweepTotal * totalRatio;
    if (activeSweep <= 0 || pCtWatts <= 0) return;

    final nativeShare = (pNativeWatts / pCtWatts).clamp(0.0, 1.0);
    final virtualShare = (pVirtualWatts / pCtWatts).clamp(0.0, 1.0);
    final residualShare = (pResidualWatts / pCtWatts).clamp(0.0, 1.0);

    double cursor = startAngle;

    void drawSegment(double share, Color color) {
      if (share <= 0) return;
      final segSweep = activeSweep * share;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, cursor, segSweep, false, paint);
      cursor += segSweep;
    }

    drawSegment(nativeShare, const Color(0xFF00E676));
    drawSegment(virtualShare, const Color(0xFF29B6F6));
    drawSegment(residualShare, const Color(0xFFFFB300));
  }

  @override
  bool shouldRepaint(covariant _RadialLoadGaugePainter oldDelegate) {
    return oldDelegate.pCtWatts != pCtWatts ||
        oldDelegate.pNativeWatts != pNativeWatts ||
        oldDelegate.pVirtualWatts != pVirtualWatts ||
        oldDelegate.pResidualWatts != pResidualWatts;
  }
}
