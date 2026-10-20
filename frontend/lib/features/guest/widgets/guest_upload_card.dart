import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../dependency_analysis/providers/analysis_provider.dart';
import 'guest_result_view.dart';
import 'sample_data.dart';

class GuestUploadCard extends StatefulWidget {
  const GuestUploadCard({
    super.key,
    required this.onSignInTap,
    required this.onRegisterTap,
  });

  final VoidCallback onSignInTap;
  final VoidCallback onRegisterTap;

  @override
  State<GuestUploadCard> createState() => _GuestUploadCardState();
}

class _GuestUploadCardState extends State<GuestUploadCard> {
  Future<void> _pickFile(BuildContext context) async {
    final provider = context.read<AnalysisProvider>();
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['yaml', 'txt', 'json'],
      withData: true,
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

  void _loadSample(SampleDependencyFile sample) {
    final provider = context.read<AnalysisProvider>();
    provider.selectFile(sample.filename, sample.bytes);
    // Automatically trigger genuine guest analysis on the real backend!
    provider.analyzeGuest();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AnalysisProvider>();
    final text = Theme.of(context).textTheme;

    // If an analysis has already completed in guest mode, show the limited result view!
    if (p.status == AnalysisStatus.success && p.result != null) {
      return AppCard(
        padding: const EdgeInsets.all(24),
        child: GuestResultView(
          result: p.result!,
          onSignInTap: widget.onSignInTap,
          onRegisterTap: widget.onRegisterTap,
          onResetTap: () {
            p.clearFile();
            p.reset();
          },
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.rocket_launch_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Dependency Governance Sandbox',
                      style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Test the genuine analysis pipeline without an account. Limited to 5 packages in guest mode.',
                      style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Loading View
          if (p.isLoading) ...[
            _GuestAnalyzingIndicator(fileName: p.fileName ?? 'dependency file'),
          ] else ...[
            // Dropzone or Selected File
            if (!p.hasFile)
              _Dropzone(onPick: () => _pickFile(context))
            else
              _SelectedFileBar(
                name: p.fileName!,
                size: p.fileSize ?? 0,
                onChange: () => _pickFile(context),
                onRemove: p.clearFile,
              ),

            // Error displays
            if (p.fileError != null) ...[
              const SizedBox(height: 14),
              _Banner(
                title: 'File Rejected',
                message: p.fileError!,
                color: AppColors.critical,
                icon: Icons.error_outline,
              ),
            ],
            if (p.error != null) ...[
              const SizedBox(height: 14),
              _Banner(
                title: p.error!.title,
                message: p.error!.message,
                color: AppColors.critical,
                icon: Icons.warning_amber_rounded,
              ),
            ],

            // Action button if a file was selected
            if (p.hasFile) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => p.analyzeGuest(),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Run Real Guest Analysis (Backend Verified)'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Quick Samples Row
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flash_on_outlined, size: 16, color: Color(0xFFEAB308)),
                    const SizedBox(width: 6),
                    Text(
                      'Or test instantly with a verified real-world project:',
                      style: text.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final sample in SampleDependencyFiles.all)
                      OutlinedButton.icon(
                        onPressed: () => _loadSample(sample),
                        icon: const Icon(Icons.file_present_outlined, size: 16),
                        label: Text(
                          '${sample.name} (${sample.filename})',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          side: const BorderSide(color: AppColors.border),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
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
      borderRadius: BorderRadius.circular(14),
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withAlpha(70),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withAlpha(40)),
              ),
              child: const Icon(
                Icons.cloud_upload_outlined,
                size: 28,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Drag & drop or click to upload your dependency file',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Evaluated against live OSV.dev advisories & our ML maintenance prediction model',
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: const [
                _Badge('pubspec.yaml (Flutter/Dart)'),
                _Badge('requirements.txt (Python)'),
                _Badge('package.json (Node.js)'),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Max file size: 1 MB',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SelectedFileBar extends StatelessWidget {
  const _SelectedFileBar({
    required this.name,
    required this.size,
    required this.onChange,
    required this.onRemove,
  });

  final String name;
  final int size;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.description_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  size < 1024 ? '$size B' : '${(size / 1024).toStringAsFixed(1)} KB',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
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

class _GuestAnalyzingIndicator extends StatelessWidget {
  const _GuestAnalyzingIndicator({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 20),
          Text(
            'Analyzing $fileName',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Extracting packages · Querying OSV.dev advisories · Running 16-feature ML maintenance model',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
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

class _Banner extends StatelessWidget {
  const _Banner({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
  });

  final String title;
  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontSize: 13,
                  ),
                ),
                Text(
                  message,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
