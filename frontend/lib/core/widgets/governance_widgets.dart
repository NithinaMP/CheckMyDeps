import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 2026-10-21 14:05 (local time).
String formatDateTime(DateTime? d) {
  if (d == null) return 'unknown date';
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

/// Section heading with an optional subtitle and trailing action.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
    Expanded(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: AppColors.textPrimary,
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
          ),
      ],
    ),
    ),
    ?trailing,
    ],
    );
    }
}

/// Lays tiles out in as many equal columns as fit (1 on phones, 3 on desktop).
class MetricGrid extends StatelessWidget {
  const MetricGrid({
    super.key,
    required this.children,
    this.minTileWidth = 280,
    this.gap = 16,
  });

  final List<Widget> children;
  final double minTileWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        var columns = ((width + gap) / (minTileWidth + gap)).floor();
        if (columns < 1) columns = 1;
        if (columns > children.length) columns = children.length;
        final tileWidth = (width - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}

/// Stacked bar + legend for a {LOW, MEDIUM, HIGH, CRITICAL} -> count map.
class RiskDistributionBar extends StatelessWidget {
  const RiskDistributionBar({super.key, required this.distribution});

  final Map<String, int> distribution;

  static const List<String> _order = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'];

  String _label(String level) =>
      '${level[0]}${level.substring(1).toLowerCase()}';

  @override
  Widget build(BuildContext context) {
    final total =
    _order.fold<int>(0, (sum, level) => sum + (distribution[level] ?? 0));
    if (total == 0) {
      return const Text(
        'No analysed dependencies yet.',
        style: TextStyle(color: AppColors.textMuted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                for (final level in _order)
                  if ((distribution[level] ?? 0) > 0)
                    Expanded(
                      flex: distribution[level]!,
                      child: ColoredBox(color: AppColors.riskColor(level)),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            for (final level in _order)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.riskColor(level),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_label(level)} ${distribution[level] ?? 0}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}