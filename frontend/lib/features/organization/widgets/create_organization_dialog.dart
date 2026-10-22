import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/organization_provider.dart';

/// Asks for an organisation name and registers it. Pops `true` on success.
class CreateOrganizationDialog extends StatefulWidget {
  const CreateOrganizationDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreateOrganizationDialog(),
    );
    return created ?? false;
  }

  @override
  State<CreateOrganizationDialog> createState() =>
      _CreateOrganizationDialogState();
}

class _CreateOrganizationDialogState extends State<CreateOrganizationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<OrganizationProvider>().clearActionError();
      }
    });
  }


  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Mirrors the backend rule: 2-80 characters after trimming.
  String? _validate(String? value) {
    final v = (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    if (v.length < 2) return 'Enter at least 2 characters';
    if (v.length > 80) return 'Use 80 characters or fewer';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await context
        .read<OrganizationProvider>()
        .createOrganization(_name.text.trim());
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrganizationProvider>();
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Create organisation',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You will be the organisation\'s admin.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                autofocus: true,
                enabled: !org.isBusy,
                maxLength: 80,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Organisation name'),
                validator: _validate,
                onFieldSubmitted: (_) => _submit(),
              ),
              if (org.actionError != null) ...[
                const SizedBox(height: 8),
                Text(
                  org.actionError!.message,
                  style: const TextStyle(color: AppColors.critical, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: org.isBusy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: org.isBusy ? null : _submit,
          child: org.isBusy
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Text('Create'),
        ),
      ],
    );
  }
}
