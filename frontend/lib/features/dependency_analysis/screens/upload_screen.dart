import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common_widgets.dart';
import '../providers/analysis_provider.dart';

class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key, required this.onAnalysisComplete});

  final VoidCallback onAnalysisComplete;

  Future<void> _pick(BuildContext context) async {
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

  Future<void> _analyze(BuildContext context) async {
    final ok = await context.read<AnalysisProvider>().analyze();
    if (ok && context.mounted) onAnalysisComplete();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AnalysisProvider>();

    final main = AppCard(
      padding: const EdgeInsets.all(28),
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _analyze(context),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('Run governance analysis'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
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
          subtitle:
              'Upload a dependency manifest to run a full governance analysis.',
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
          return Column(
            children: [main, const SizedBox(height: 16), const _InfoCard()],
          );
        }),
      ],
    );
  }
}

// ─────────────────────────── dropzone ─────────────────────────────────────

class _Dropzone extends StatefulWidget {
  const _Dropzone({required this.onPick});
  final VoidCallback onPick;

  @override
  State<_Dropzone> createState() => _DropzoneState();
}

class _DropzoneState extends State<_Dropzone>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPick,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          decoration: BoxDecoration(
            color: _hovered
                ? AppColors.primary.withAlpha(18)
                : AppColors.primary.withAlpha(8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: _hovered
                  ? AppColors.primary
                  : AppColors.primary.withAlpha(100),
              radius: 16,
              dashLength: 8,
              gapLength: 5,
            ),
            child: Column(
              children: [
                // Animated upload icon
                AnimatedBuilder(
                  animation: _shimmer,
                  builder: (context, child) {
                    final offset =
                        math.sin(_shimmer.value * 2 * math.pi) * 4;
                    return Transform.translate(
                      offset: Offset(0, offset),
                      child: child,
                    );
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withAlpha(30),
                          const Color(0xFF7C3AED).withAlpha(20),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withAlpha(60),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.cloud_upload_rounded,
                      size: 34,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Drop your dependency file here',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    children: [
                      const TextSpan(text: 'or '),
                      TextSpan(
                        text: 'click to browse',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: ' your computer'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: const [
                    _FormatChip(
                      label: 'pubspec.yaml',
                      icon: Icons.flutter_dash,
                    ),
                    _FormatChip(
                      label: 'requirements.txt',
                      icon: Icons.code_rounded,
                    ),
                    _FormatChip(
                      label: 'package.json',
                      icon: Icons.javascript_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Maximum 1 MB',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.dashLength,
    required this.gapLength,
  });

  final Color color;
  final double radius;
  final double dashLength;
  final double gapLength;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double dist = 0;
      bool draw = true;
      while (dist < metric.length) {
        final len = draw ? dashLength : gapLength;
        if (draw) {
          canvas.drawPath(
            metric.extractPath(dist, dist + len),
            paint,
          );
        }
        dist += len;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.dashLength != dashLength;
}

// ─────────────────────────── format chip ──────────────────────────────────

class _FormatChip extends StatelessWidget {
  const _FormatChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── selected file ────────────────────────────────────

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
        color: AppColors.primary.withAlpha(8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withAlpha(30),
                  const Color(0xFF7C3AED).withAlpha(20),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.description_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatSize(size),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Change'),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────── analyzing view ──────────────────────────────────

class _AnalyzingView extends StatefulWidget {
  const _AnalyzingView({required this.fileName});
  final String fileName;

  @override
  State<_AnalyzingView> createState() => _AnalyzingViewState();
}

class _AnalyzingViewState extends State<_AnalyzingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _stepIndex = 0;

  static const _steps = [
    'Parsing dependency manifest…',
    'Checking OSV.dev for vulnerabilities…',
    'Evaluating license compliance…',
    'Running ML maintenance prediction…',
    'Scoring and ranking dependencies…',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          _controller.reset();
          if (mounted) {
            setState(() {
              _stepIndex = (_stepIndex + 1) % _steps.length;
            });
          }
          _controller.forward();
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          // Pulsing shield icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.9, end: 1.05),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            builder: (_, scale, child) => Transform.scale(
              scale: scale,
              child: child,
            ),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(60),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Analyzing ${widget.fileName}',
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _steps[_stepIndex],
              key: ValueKey(_stepIndex),
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            child: LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: AppColors.surfaceSubtle,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Each package is checked against OSV.dev and GitHub. This takes a minute or two.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── error banner ─────────────────────────────────

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
        color: AppColors.critical.withAlpha(12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.critical.withAlpha(70)),
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
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.critical,
                  ),
                ),
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

// ──────────────────────────── info card ───────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    Widget step(
      int num,
      IconData icon,
      Color color,
      String title,
      String body,
    ) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withAlpha(50)),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: text.bodySmall
                          ?.copyWith(color: AppColors.textSecondary, height: 1.4),
                    ),
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
          Text(
            'What gets checked',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Every analysis runs these checks against real data.',
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          step(1, Icons.gavel_rounded, AppColors.primary, 'License compliance',
              'Each package license is matched against your configured policy.'),
          step(2, Icons.security_rounded, AppColors.high,
              'Vulnerability detection',
              'CVEs from OSV.dev for the declared version.'),
          step(3, Icons.psychology_rounded, const Color(0xFF7C3AED),
              'ML maintenance prediction',
              'A scikit-learn model predicts if the repository is still maintained, based on commit activity.'),
          step(4, Icons.policy_rounded, AppColors.medium, 'Policy enforcement',
              'Governance score is computed against your policy rules.'),
        ],
      ),
    );
  }
}
