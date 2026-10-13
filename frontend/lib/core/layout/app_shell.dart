import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/dependency_analysis/providers/analysis_provider.dart';
import '../../features/dependency_analysis/screens/upload_screen.dart';
import '../theme/app_colors.dart';

class _NavItem {
  const _NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Sidebar layout shown after login. Wide screens get a fixed sidebar,
/// narrow screens get an app bar with a drawer.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.onSignedOut});

  /// Called after sign-out so the caller can navigate to the login screen.
  final VoidCallback onSignedOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  // More destinations (Dependencies, History...) are added as they are built.
  static const _items = [
    _NavItem('Dashboard', Icons.dashboard_outlined),
    _NavItem('Upload & Analyze', Icons.upload_file_outlined),
  ];

  void _select(int i) => setState(() => _index = i);

  Future<void> _signOut() async {
    context.read<AnalysisProvider>().reset();
    await FirebaseAuth.instance.signOut();
    if (mounted) widget.onSignedOut();
  }

  Widget _page() {
    switch (_index) {
      case 1:
        return UploadScreen(onAnalysisComplete: () => _select(0));
      default:
        return DashboardScreen(
          onUploadTap: () => _select(1),
          onViewAll: () => _select(1),
          onOpenDependency: (dependency) {
            // TODO: Open the selected dependency's details.
          },
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
            padding: EdgeInsets.all(wide ? 32 : 16),
            child: _page(),
          ),

        ),
      );

      if (wide) {
        return Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 248,
                child: _Sidebar(
                  items: _items,
                  selected: _index,
                  onSelect: _select,
                  onSignOut: _signOut,
                ),
              ),
              Expanded(child: content),
            ],
          ),
        );
      }

      return Scaffold(
        appBar: AppBar(
          title: const Text('DepGuard'),
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
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
    final email = FirebaseAuth.instance.currentUser?.email ?? 'Signed in';

    return Container(
      color: AppColors.navy,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_outlined,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DepGuard',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        Text('Dependency Governance',
                            style:
                                TextStyle(color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < items.length; i++)
              _NavTile(
                item: items[i],
                selected: i == selected,
                onTap: () => onSelect(i),
              ),
            const Spacer(),
            const Divider(color: Colors.white12, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white12,
                    child: Text(
                      email.isNotEmpty ? email[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(email,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ),
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout, color: Colors.white70),
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

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? Colors.white.withAlpha(26) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(item.icon,
                    size: 20, color: selected ? Colors.white : Colors.white60),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
