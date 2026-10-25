import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../repositories/auth_repository.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../shared/widgets/app_icons.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notif = true;
  bool _loc = true;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return ColoredBox(
      color: AppColors.bg,
      child: userAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.orange),
        ),
        error: (e, s) => Center(
          child: Text(
            "Couldn't load your account.",
            style: AppText.ui(13, FontWeight.w400, color: AppColors.muted),
          ),
        ),
        data: (u) => _content(context, u), // Note: Pass context explicitly here
      ),
    );
  }

  Widget _content(BuildContext context, AuthUser? u) {
    if (u == null) {
      return Center(
        child: Text(
          "You are not signed in.",
          style: AppText.ui(14, FontWeight.w500, color: AppColors.muted),
        ),
      );
    }

    final rows = <_Row>[
      const _Row(Icons.bookmark_border_rounded, 'Saved Places', '12 places saved'),
      _Row(
        Icons.tune_rounded,
        'Travel Preferences',
        'View or edit your saved preferences',
        onTap: () => context.push(AppRoutes.preferences, extra: u.email),
      ),
      _Row(
        Icons.history_rounded,
        'Past Trips',
        'View your trip history',
        onTap: () => context.go(AppRoutes.trips),
      ),
      _Row(
        Icons.notifications_none_rounded,
        'Notifications',
        'Departure reminders & updates',
        toggle: true,
        value: _notif,
        onChanged: (v) => setState(() => _notif = v),
      ),
      _Row(
        Icons.location_on_outlined,
        'Privacy & Location',
        'Manage location sharing',
        toggle: true,
        value: _loc,
        onChanged: (v) => setState(() => _loc = v),
      ),
      const _Row(Icons.help_outline_rounded, 'Help & Support', 'FAQs and contact'),
    ];

    final stats = [
      (u.tripsCount, 'Trips'),
      (u.friendsCount, 'Friends'),
      (u.placesCount, 'Places'),
    ];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  'Profile',
                  style: AppText.ui(20, FontWeight.w800, color: AppColors.navy),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.orange.withValues(alpha: 0.18),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  u.initials,
                  style: AppText.ui(28, FontWeight.w800, color: AppColors.orange),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              u.fullName.isEmpty ? 'Taralets User' : u.fullName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.ui(21, FontWeight.w800, color: AppColors.navy),
            ),
            const SizedBox(height: 4),
            Text(
              u.email,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.ui(13, FontWeight.w400, color: AppColors.muted),
            ),
            const SizedBox(height: 3),
            Text(
              '@${u.username}',
              textAlign: TextAlign.center,
              style: AppText.ui(12, FontWeight.w600, color: AppColors.orange),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navy.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${stats[i].$1}',
                            style: AppText.ui(
                              18,
                              FontWeight.w800,
                              color: AppColors.orange,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            stats[i].$2,
                            style: AppText.ui(
                              11,
                              FontWeight.w600,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i < stats.length - 1)
                      Container(width: 1, height: 34, color: AppColors.border),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navy.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: rows[i].onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          border: i < rows.length - 1
                              ? const Border(
                                  bottom: BorderSide(color: AppColors.border),
                                )
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.orange.withValues(alpha: 0.09),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                rows[i].icon,
                                size: 20,
                                color: AppColors.orange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rows[i].label,
                                    style: AppText.ui(
                                      14,
                                      FontWeight.w700,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    rows[i].sub,
                                    style: AppText.ui(
                                      11,
                                      FontWeight.w400,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (rows[i].toggle)
                              _Switch(
                                on: rows[i].value,
                                onTap: () =>
                                    rows[i].onChanged!(!rows[i].value),
                              )
                            else
                              AppIcons.chevronRight(),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                final router = GoRouter.of(context);
                await ref.read(authRepositoryProvider).logout();
                ref.invalidate(currentUserProvider);
                ref.invalidate(myTripsProvider);
                router.go(AppRoutes.login);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.orange.withValues(alpha: 0.2),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Log Out',
                      style: AppText.ui(
                        14,
                        FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row {
  const _Row(
    this.icon,
    this.label,
    this.sub, {
    this.toggle = false,
    this.value = false,
    this.onChanged,
    this.onTap,
  });
  final IconData icon;
  final String label, sub;
  final bool toggle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onTap;
}

/// Figma toggle: 44x24, 18dp knob, orange when on, #D1D5DB when off.
class _Switch extends StatelessWidget {
  const _Switch({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 24,
        decoration: BoxDecoration(
          color: on ? AppColors.orange : AppColors.navInactive,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              top: 3,
              left: on ? 23 : 3,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
