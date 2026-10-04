import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/app_icons.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/app_text.dart';

/// Hosts the active tab plus the Figma bottom bar:
/// 72dp tall, white, 1px #F3F4F6 top border, 22dp icons, 10sp/700 labels,
/// orange when active and #D1D5DB when inactive.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static final List<_Tab> _tabs = [
    _Tab('Home', AppIcons.home),
    _Tab('Discover', AppIcons.compass),
    _Tab('Trips', AppIcons.map),
    _Tab('Itinerary', AppIcons.calendar),
    _Tab('Profile', AppIcons.user),
  ];

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(bottom: false, child: navigationShell),
      bottomNavigationBar: Container(
        height: AppSizes.bottomNavHeight + bottomInset,
        padding: EdgeInsets.only(bottom: 8 + bottomInset),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.navDivider)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              Expanded(
                child: _NavItem(
                  tab: _tabs[i],
                  active: navigationShell.currentIndex == i,
                  onTap: () => _onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab(this.label, this.icon);
  final String label;
  final Widget Function({Color color, double size}) icon;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final _Tab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.orange : AppColors.navInactive;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            tab.icon(color: color, size: 22),
            const SizedBox(height: 3),
            Text(
              tab.label,
              style: AppText.ui(10, FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
