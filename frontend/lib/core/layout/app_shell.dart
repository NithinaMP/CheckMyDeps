import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/dependency_analysis/models/analysis_result.dart';
import '../../features/dependency_analysis/providers/analysis_provider.dart';
import '../../features/dependency_analysis/screens/dependencies_screen.dart';
import '../../features/dependency_analysis/screens/dependency_detail_screen.dart';
import '../../features/dependency_analysis/screens/upload_screen.dart';
import '../../features/history/screens/history_screen.dart';
import '../../features/policy/screens/policy_screen.dart';
import '../theme/app_colors.dart';

class _NavItem {
  const _NavItem(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Sidebar shell for the authenticated experience.
/// Wide screens (≥ 900 px) show a fixed sidebar; narrow screens get a drawer.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.onSignedOut});

  final VoidCallback onSignedOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _items = [
    _NavItem('Dashboard', Icons.dashboard_outlined, Icons.dashboard_rounded),
    _NavItem('Upload & Analyze', Icons.upload_file_outlined, Icons.upload_file_rounded),
    _NavItem('Dependencies', Icons.inventory_2_outlined, Icons.inventory_2_rounded),
    _NavItem('History', Icons.history_outlined, Icons.history_rounded),
    _NavItem('Policy', Icons.policy_outlined, Icons.policy_rounded),
  ];

  void _select(int i) => setState(() => _index = i);

  Future<void> _signOut() async {
    context.read<AnalysisProvider>().reset();
    await FirebaseAuth.instance.signOut();
    if (mounted) widget.onSignedOut();
  }

  void _openDependency(DependencyResult dependency) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DependencyDetailScreen(dependency: dependency),
      ),
    );
  }

  Widget _page() {
    switch (_index) {
      case 1:
        return UploadScreen(onAnalysisComplete: () => _select(0));
      case 2:
        return DependenciesScreen(
          onOpenDependency: _openDependency,
          onUploadTap: () => _select(1),
        );
      case 3:
        return HistoryScreen(
          onOpened: () => _select(0),
          onUploadTap: () => _select(1),
        );
      case 4:
        return const PolicyScreen();
      default:
        return DashboardScreen(
          onUploadTap: () => _select(1),
          onViewAll: () => _select(2),
          onOpenDependency: _openDependency,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;

      final content = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(wide ? 32 : 20),
            child: _page(),
          ),
        ),
      );

      if (wide) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Row(
            children: [
              SizedBox(
                width: 256,
                child: _Sidebar(
                  items: _items,
                  selected: _index,
                  onSelect: _select,
                  onSignOut: _signOut,
                ),
              ),
              Expanded(
                child: Container(
                  color: AppColors.background,
                  child: content,
                ),
              ),
            ],
          ),
        );
      }

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'CheckMyDeps',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        drawer: Drawer(
          backgroundColor: AppColors.navy,
          child: _Sidebar(
            items: _items,
            selected: _index,
            onSelect: (i) {
              Navigator.of(context).pop();
              _select(i);
            },
            onSignOut: _signOut,
          ),
        ),
        body: content,
      );
    });
  }
}

// ─────────────────────────────────────────────────── Sidebar ───────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.onSignOut,
  });

  final List<_NavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Signed in';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navy,
        border: Border(right: BorderSide(color: AppColors.borderDark, width: 1)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Brand ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 28),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withAlpha(80),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CheckMyDeps',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Dependency Governance',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Divider label ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'NAVIGATION',
                style: TextStyle(
                  color: Colors.white.withAlpha(40),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            // ── Nav tiles ──────────────────────────────────────
            for (var i = 0; i < items.length; i++)
              _NavTile(
                item: items[i],
                selected: i == selected,
                onTap: () => onSelect(i),
              ),

            const Spacer(),

            // ── Footer divider ─────────────────────────────────
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.white.withAlpha(15),
            ),
            const SizedBox(height: 12),

            // ── User row ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 8, 16),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Text(
                          'Individual plan',
                          style: TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tooltip(
                    message: 'Sign out',
                    child: IconButton(
                      onPressed: onSignOut,
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      color: Colors.white38,
                      hoverColor: Colors.white12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────── NavTile ───────────────

class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary.withAlpha(30)
                  : _hovered
                  ? Colors.white.withAlpha(8)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: active
                  ? Border.all(color: AppColors.primary.withAlpha(60), width: 1)
                  : Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                Icon(
                  active ? widget.item.activeIcon : widget.item.icon,
                  size: 18,
                  color: active ? AppColors.primary : const Color(0xFF64748B),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.item.label,
                    style: TextStyle(
                      color: active ? Colors.white : const Color(0xFF94A3B8),
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                if (active)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
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
