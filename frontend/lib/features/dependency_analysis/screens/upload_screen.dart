import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../providers/analysis_provider.dart';

class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key, required this.onAnalysisComplete});

  /// Called after a successful analysis (the shell switches to the dashboard).
  final VoidCallback onAnalysisComplete;

  Future<void> _pick(BuildContext context) async {
    final provider = context.read<AnalysisProvider>();
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['yaml', 'txt', 'json'],
      withData: true, // required on web: there is no file path, only bytes
    );
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      provider.rejectFile('Could not read the selected file.');
      return;
    }
    provider.selectFile(file.name, bytes);
  }

  Future<void> _analyze(BuildContext context) async {
    final ok = await context.read<AnalysisProvider>().analyze();
    if (ok && context.mounted) onAnalysisComplete();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AnalysisProvider>();

    final main = AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.isLoading)
            _AnalyzingView(fileName: p.fileName ?? '')
          else ...[
            if (!p.hasFile)
              _Dropzone(onPick: () => _pick(context))
            else
              _SelectedFile(
                name: p.fileName!,
                size: p.fileSize ?? 0,
                onChange: () => _pick(context),
                onRemove: p.clearFile,
              ),
            if (p.fileError != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(title: 'File not accepted', message: p.fileError!),
            ],
            if (p.error != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(title: p.error!.title, message: p.error!.message),
            ],
            if (p.hasFile) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _analyze(context),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Analyze dependencies'),
                ),
              ),
            ],
          ],
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(
          title: 'Upload & Analyze',
          subtitle: 'Upload a dependency file to run a governance analysis.',
        ),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, c) {
          if (c.maxWidth >= 860) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: main),
                const SizedBox(width: 24),
                const Expanded(flex: 2, child: _InfoCard()),
              ],
            );
          }
          return Column(children: [main, const SizedBox(height: 16), const _InfoCard()]);
        }),
      ],
    );
  }
}

class _Dropzone extends StatelessWidget {
  const _Dropzone({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPick,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withAlpha(70)),
        ),
        child: Column(
          children: [
            const Icon(Icons.cloud_upload_outlined,
                size: 46, color: AppColors.primary),
            const SizedBox(height: 14),
            Text('Select a dependency file',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Click to browse your computer',
                style: text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _FormatChip('pubspec.yaml'),
                _FormatChip('requirements.txt'),
                _FormatChip('package.json'),
              ],
            ),
            const SizedBox(height: 12),
            Text('Maximum size 1 MB',
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _SelectedFile extends StatelessWidget {
  const _SelectedFile({
    required this.name,
    required this.size,
    required this.onChange,
    required this.onRemove,
  });

  final String name;
  final int size;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  String _formatSize(int bytes) =>
      bytes < 1024 ? '$bytes B' : '${(bytes / 1024).toStringAsFixed(1)} KB';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(26),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.description_outlined,
                color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(_formatSize(size),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          TextButton(onPressed: onChange, child: const Text('Change')),
          IconButton(
            tooltip: 'Remove',
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
    );
  }
}

class _AnalyzingView extends StatelessWidget {
  const _AnalyzingView({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const SizedBox(
              width: 44, height: 44, child: CircularProgressIndicator()),
          const SizedBox(height: 20),
          Text('Analyzing $fileName',
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Each package is checked against its registry, GitHub activity and '
            'OSV.dev. This can take a minute or two.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          const ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            child: LinearProgressIndicator(minHeight: 6),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.critical.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.critical.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.critical, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.critical)),
                const SizedBox(height: 2),
                Text(message, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget row(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(body,
                        style: text.bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        );

    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What gets checked',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          row(Icons.gavel_outlined, 'License compliance',
              'Each package license is checked against your policy.'),
          row(Icons.security_outlined, 'Known vulnerabilities',
              'Looked up on OSV.dev for the declared version.'),
          row(Icons.update_outlined, 'Maintenance health',
              'A machine-learning model predicts whether the repository is still maintained.'),
        ],
      ),
    );
  }
}
