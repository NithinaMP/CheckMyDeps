import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/organization_provider.dart';
import 'create_organization_dialog.dart';

/// Sidebar control: Personal workspace / each organisation / Create organisation.
class WorkspaceSwitcher extends StatelessWidget {
  const WorkspaceSwitcher({super.key, required this.onChanged});

  /// Called after the active workspace changed (AppShell resets its page index).
  final VoidCallback onChanged;

  static const _personal = 'personal';
  static const _create = 'create';
  static const _retry = 'retry';
  static const _orgPrefix = 'org:';

  Future<void> _selected(BuildContext context, String value) async {
    final org = context.read<OrganizationProvider>();
    if (value == _personal) {
      org.switchToPersonal();
      onChanged();
    } else if (value == _retry) {
      await org.load();
    } else if (value == _create) {
      final created = await CreateOrganizationDialog.show(context);
      if (created) onChanged();
    } else if (value.startsWith(_orgPrefix)) {
      if (org.switchToOrganization(value.substring(_orgPrefix.length))) {
        onChanged();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrganizationProvider>();
    final active = org.activeMembership;
    final title = active?.name ?? 'Personal workspace';
    final subtitle = active != null
        ? active.role.label
        : org.isLoading
        ? 'Loading organisations…'
        : 'Individual';

    return PopupMenuButton<String>(
      tooltip: 'Switch workspace',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      color: AppColors.navySurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderDark),
      ),
      onSelected: (v) => _selected(context, v),
      itemBuilder: (_) => [
        _item(_personal, Icons.person_outline_rounded, 'Personal workspace',
            selected: active == null),
        if (org.loadError != null)
          _item(_retry, Icons.refresh_rounded, 'Could not load organisations — retry'),
        for (final m in org.memberships)
          _item('$_orgPrefix${m.id}', Icons.apartment_rounded, m.name,
              trailing: m.role.label, selected: active?.id == m.id),
        const PopupMenuItem<String>(
          enabled: false,
          height: 9,
          padding: EdgeInsets.zero,
          child: Divider(height: 1, color: AppColors.borderDark),
        ),
        _item(_create, Icons.add_business_outlined, 'Create organisation'),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withAlpha(20)),
        ),
        child: Row(
          children: [
            Icon(
              active != null ? Icons.apartment_rounded : Icons.person_outline_rounded,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                  ),
                ],
              ),
            ),
            const Icon(Icons.unfold_more_rounded, size: 16, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _item(
      String value,
      IconData icon,
      String label, {
        String? trailing,
        bool selected = false,
      }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 16, color: selected ? AppColors.primary : Colors.white54),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFFCBD5E1),
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(trailing,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
          ],
        ],
      ),
    );
  }
}
