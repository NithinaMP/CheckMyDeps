import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/status_badges.dart';
import '../../dependency_analysis/providers/analysis_provider.dart';

/// Lets the user change the rules dependencies are checked against.
/// The saved policy is sent with the next analysis (policy_json).
class PolicyScreen extends StatefulWidget {
  const PolicyScreen({super.key});

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> {
  // Same values as the backend's DEFAULT_POLICY (app/policy_defaults.py).
  static const Map<String, dynamic> _defaultPolicy = {
    'allowed_licenses': ['MIT', 'Apache-2.0', 'BSD', 'ISC', 'Unlicense'],
    'restricted_licenses': ['LGPL', 'MPL'],
    'prohibited_licenses': ['GPL', 'AGPL'],
    'max_vulnerability_severity': 'MEDIUM',
    'require_maintained': true,
  };

  static const List<String> _severities = [
    'NONE',
    'LOW',
    'MEDIUM',
    'HIGH',
    'CRITICAL',
  ];

  late final TextEditingController _allowed;
  late final TextEditingController _restricted;
  late final TextEditingController _prohibited;
  late String _maxSeverity;
  late bool _requireMaintained;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final current = context.read<AnalysisProvider>().policy ?? _defaultPolicy;
    _allowed = TextEditingController(text: _list(current['allowed_licenses']).join(', '));
    _restricted =
        TextEditingController(text: _list(current['restricted_licenses']).join(', '));
    _prohibited =
        TextEditingController(text: _list(current['prohibited_licenses']).join(', '));
    final sev = current['max_vulnerability_severity'];
    _maxSeverity = (sev is String && _severities.contains(sev.toUpperCase()))
        ? sev.toUpperCase()
        : 'MEDIUM';
    _requireMaintained = current['require_maintained'] is bool
        ? current['require_maintained'] as bool
        : true;
  }

  @override
  void dispose() {
    _allowed.dispose();
    _restricted.dispose();
    _prohibited.dispose();
    super.dispose();
  }

  List<String> _list(dynamic v) =>
      v is List ? v.map((e) => e.toString()).toList() : <String>[];

  List<String> _parse(String raw) => raw
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  void _save() {
    context.read<AnalysisProvider>().setPolicy({
      'allowed_licenses': _parse(_allowed.text),
      'restricted_licenses': _parse(_restricted.text),
      'prohibited_licenses': _parse(_prohibited.text),
      'max_vulnerability_severity': _maxSeverity,
      'require_maintained': _requireMaintained,
    });
    setState(() => _saved = true);
  }

  void _reset() {
    context.read<AnalysisProvider>().setPolicy(null);
    setState(() {
      _allowed.text = _list(_defaultPolicy['allowed_licenses']).join(', ');
      _restricted.text = _list(_defaultPolicy['restricted_licenses']).join(', ');
      _prohibited.text = _list(_defaultPolicy['prohibited_licenses']).join(', ');
      _maxSeverity = 'MEDIUM';
      _requireMaintained = true;
      _saved = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final custom = context.watch<AnalysisProvider>().policy != null;
    final used = context.watch<AnalysisProvider>().result?.policyUsed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(
          title: 'Policy',
          subtitle: 'The rules every dependency is checked against',
        ),
        const SizedBox(height: 20),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Governance policy',
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(width: 12),
                  StatusBadge(custom ? 'Custom' : 'Default',
                      custom ? AppColors.primary : AppColors.neutral),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Separate license names with commas. A policy change applies to '
                'the next analysis you run; upload your file again to use it.',
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              _field(_allowed, 'Allowed licenses', 'Treated as compliant'),
              const SizedBox(height: 14),
              _field(_restricted, 'Restricted licenses',
                  'Allowed only after a manual review'),
              const SizedBox(height: 14),
              _field(_prohibited, 'Prohibited licenses',
                  'Reported as policy violations'),
              const SizedBox(height: 14),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Highest vulnerability severity allowed',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _maxSeverity,
                    isExpanded: true,
                    items: [
                      for (final s in _severities)
                        DropdownMenuItem<String>(value: s, child: Text(s)),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _maxSeverity = value;
                          _saved = false;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Require maintained repositories'),
                subtitle: const Text(
                    'Dependencies predicted to be unmaintained count as violations'),
                value: _requireMaintained,
                onChanged: (value) => setState(() {
                  _requireMaintained = value;
                  _saved = false;
                }),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save policy'),
                  ),
                  OutlinedButton(
                    onPressed: _reset,
                    child: const Text('Reset to default'),
                  ),
                  if (_saved)
                    Text('Saved. It will be used for your next analysis.',
                        style: text.bodySmall?.copyWith(color: AppColors.low)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'The policy is kept for this session only.',
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (used != null && used.isNotEmpty) ...[
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Used in the latest analysis',
                    style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                _usedLine(text, 'Allowed', _list(used['allowed_licenses']).join(', ')),
                _usedLine(text, 'Restricted', _list(used['restricted_licenses']).join(', ')),
                _usedLine(text, 'Prohibited', _list(used['prohibited_licenses']).join(', ')),
                _usedLine(text, 'Max severity',
                    '${used['max_vulnerability_severity'] ?? '—'}'),
                _usedLine(text, 'Require maintained',
                    used['require_maintained'] == true ? 'Yes' : 'No'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _field(TextEditingController controller, String label, String helper) {
    return TextField(
      controller: controller,
      onChanged: (_) {
        if (_saved) setState(() => _saved = false);
      },
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _usedLine(TextTheme text, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(label,
                style: text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value.isEmpty ? '—' : value, style: text.bodyMedium),
          ),
        ],
      ),
    );
  }
}
