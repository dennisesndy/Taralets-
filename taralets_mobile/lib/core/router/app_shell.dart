import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/taralets_bottom_nav.dart';
import '../constants/app_colors.dart';

/// Hosts the active tab plus the floating 4-tab bottom bar.
/// Tabs: Home, Search (Discover), Map (Trips), Profile.
/// The Itinerary branch still exists in the router; it is just no longer a tab.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Tab index -> router branch index (branch 3 = Itinerary, skipped).
  static const List<int> _branchIndexes = [0, 1, 2, 4];

  /// While on the Itinerary branch, keep the Trips tab highlighted,
  /// since Itinerary is now reached from the Trips screen.
  int get _tabIndex {
    final i = _branchIndexes.indexOf(navigationShell.currentIndex);
    return i == -1 ? 2 : i;
  }

  void _onTap(int tabIndex) {
    final branch = _branchIndexes[tabIndex];
    navigationShell.goBranch(
      branch,
      initialLocation: branch == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Ito ang magpapalutang nang tuluyan sa bottom nav
      backgroundColor: AppColors.bg,
      body: SafeArea(bottom: false, child: navigationShell),
      bottomNavigationBar: TaraletsBottomNav(
        currentIndex: _tabIndex,
        onTap: _onTap,
      ),
    );
  }
}