import 'package:flutter/material.dart';

import '../../features/dependency_analysis/models/analysis_result.dart';
import '../theme/app_colors.dart';

/// Generic coloured pill.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, this.color, {super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

Color severityColor(String? severity) {
  switch (severity?.toUpperCase()) {
    case 'LOW':
      return AppColors.low;
    case 'MEDIUM':
      return AppColors.medium;
    case 'HIGH':
      return AppColors.high;
    case 'CRITICAL':
      return AppColors.critical;
    default:
      return AppColors.neutral;
  }
}

/// Human label for a license rule status.
String licenseLabel(String? status) {
  switch (status) {
    case 'COMPLIANT':
      return 'Compliant';
    case 'RESTRICTED':
      return 'Restricted';
    case 'NON_COMPLIANT':
      return 'Prohibited';
    case 'NOT_IN_POLICY':
      return 'Not in policy';
    default:
      return 'Unknown';
  }
}

Color licenseColor(String? status) {
  switch (status) {
    case 'COMPLIANT':
      return AppColors.low;
    case 'RESTRICTED':
      return AppColors.medium;
    case 'NON_COMPLIANT':
      return AppColors.critical;
    case 'NOT_IN_POLICY':
      return AppColors.primary;
    default:
      return AppColors.neutral;
  }
}

class LicenseBadge extends StatelessWidget {
  const LicenseBadge(this.status, {super.key});
  final String? status;

  @override
  Widget build(BuildContext context) =>
      StatusBadge(licenseLabel(status), licenseColor(status));
}

Color maintenanceColor(String status) {
  switch (status) {
    case 'Maintained':
      return AppColors.low;
    case 'Unmaintained':
      return AppColors.high;
    default:
      return AppColors.neutral;
  }
}

class MaintenanceBadge extends StatelessWidget {
  const MaintenanceBadge(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) => StatusBadge(
      status == 'Unable to determine' ? 'Undetermined' : status,
      maintenanceColor(status));
}

class PolicyBadge extends StatelessWidget {
  const PolicyBadge(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'OK':
        return const StatusBadge('Compliant', AppColors.low);
      case 'VIOLATION':
        return const StatusBadge('Violation', AppColors.critical);
      default:
        return const StatusBadge('Needs review', AppColors.medium);
    }
  }
}

/// Vulnerability badge that never claims "none" when the lookup failed.
class VulnerabilityBadge extends StatelessWidget {
  const VulnerabilityBadge(this.info, {super.key});
  final VulnerabilityInfo? info;

  @override
  Widget build(BuildContext context) {
    final v = info;
    if (v == null || !v.isVerified || v.count == null) {
      return const StatusBadge('Unverified', AppColors.neutral);
    }
    if (v.count == 0) return const StatusBadge('None', AppColors.low);
    final sev = v.highestSeverity;
    final label = (sev == null || sev == 'UNKNOWN' || sev == 'NONE')
        ? '${v.count}'
        : '${v.count} · $sev';
    return StatusBadge(label, severityColor(sev));
  }
}
