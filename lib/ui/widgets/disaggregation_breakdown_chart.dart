import 'package:flutter/material.dart';

/// Breakdown visualization for Native (`∑P_Native`) vs. Virtual (`∑P_Virtual`)
/// vs. Unmonitored Residual (`P_Residual`) load.
class DisaggregationBreakdownChart extends StatelessWidget {
  final double pCtWatts;
  final double pNativeWatts;
  final double pVirtualWatts;
  final double pResidualWatts;

  const DisaggregationBreakdownChart({
    super.key,
    required this.pCtWatts,
    required this.pNativeWatts,
    required this.pVirtualWatts,
    required this.pResidualWatts,
  });

  @override
  Widget build(BuildContext context) {
    final safeTotal = pCtWatts <= 0 ? 1.0 : pCtWatts;
    final nativeFlex = ((pNativeWatts / safeTotal) * 1000).round().clamp(1, 1000);
    final virtualFlex =
        ((pVirtualWatts / safeTotal) * 1000).round().clamp(1, 1000);
    final residualFlex =
        ((pResidualWatts / safeTotal) * 1000).round().clamp(1, 1000);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141A24),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DISAGGREGATION BREAKDOWN',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'P_Residual = P_CT - (∑P_Native + ∑P_Virtual)',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 18,
              child: Row(
                children: [
                  Expanded(
                    flex: nativeFlex,
                    child: Container(color: const Color(0xFF00E676)),
                  ),
                  Expanded(
                    flex: virtualFlex,
                    child: Container(color: const Color(0xFF29B6F6)),
                  ),
                  Expanded(
                    flex: residualFlex,
                    child: Container(color: const Color(0xFFFFB300)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _BreakdownRow(
            color: const Color(0xFF00E676),
            title: 'Native Metered (∑P_Native)',
            subtitle: 'Direct smart plug & appliance DPs',
            watts: pNativeWatts,
            totalWatts: safeTotal,
          ),
          const Divider(color: Colors.white10, height: 20),
          _BreakdownRow(
            color: const Color(0xFF29B6F6),
            title: 'Virtual Payload (∑P_Virtual)',
            subtitle: 'P_rated × (Level / 100) × State',
            watts: pVirtualWatts,
            totalWatts: safeTotal,
          ),
          const Divider(color: Colors.white10, height: 20),
          _BreakdownRow(
            color: const Color(0xFFFFB300),
            title: 'Unmonitored Residual (P_Residual)',
            subtitle: 'Inferred untracked household load',
            watts: pResidualWatts,
            totalWatts: safeTotal,
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final Color color;
  final String title;
  final String subtitle;
  final double watts;
  final double totalWatts;

  const _BreakdownRow({
    required this.color,
    required this.title,
    required this.subtitle,
    required this.watts,
    required this.totalWatts,
  });

  @override
  Widget build(BuildContext context) {
    final pct = ((watts / totalWatts) * 100.0).clamp(0.0, 100.0);
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${watts.toStringAsFixed(1)} W',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 15,
              ),
            ),
            Text(
              '${pct.toStringAsFixed(1)}%',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
