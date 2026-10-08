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
      const _Row('❤️', 'Saved Places', '12 places saved'),
      _Row(
        '🗂️',
        'Travel Preferences',
        'Update interests & dining',
        onTap: () => context.push(AppRoutes.preferences, extra: u.email),
      ),
      _Row(
        '🗺️',
        'Past Trips',
        'View your gala history',
        onTap: () => context.go(AppRoutes.trips),
      ),
      _Row(
        '🔔',
        'Notifications',
        'Departure reminders & updates',
        toggle: true,
        value: _notif,
        onChanged: (v) => setState(() => _notif = v),
      ),
      _Row(
        '📍',
        'Privacy & Location',
        'Manage location sharing',
        toggle: true,
        value: _loc,
        onChanged: (v) => setState(() => _loc = v),
      ),
      const _Row('❓', 'Help & Support', 'FAQs, contact us'),
    ];

    final stats = [
      (u.tripsCount, 'Trips'),
      (u.friendsCount, 'Friends'),
      (u.placesCount, 'Places'),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppColors.navy,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.orange.withValues(alpha: 0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    u.initials,
                    style: AppText.ui(24, FontWeight.w800, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.fullName.isEmpty ? 'Taralets User' : u.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.ui(
                          20,
                          FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${u.username}',
                        style: AppText.ui(
                          13,
                          FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (final s in stats) ...[
                            Column(
                              children: [
                                Text(
                                  '${s.$1}',
                                  style: AppText.ui(
                                    14,
                                    FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  s.$2,
                                  style: AppText.ui(
                                    10,
                                    FontWeight.w400,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                            if (s != stats.last) const SizedBox(width: 12),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Edit',
                    style: AppText.ui(12, FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
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
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              border: i < rows.length - 1
                                  ? const Border(
                                      bottom: BorderSide(color: AppColors.bg),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  rows[i].icon,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        rows[i].label,
                                        style: AppText.ui(14, FontWeight.w600),
                                      ),
                                      const SizedBox(height: 1),
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
                const SizedBox(height: 8),

                // Functional Logout Button
                GestureDetector(
                  onTap: () async {
                    final router = GoRouter.of(context);
                    await ref.read(authRepositoryProvider).logout();
                    ref.invalidate(currentUserProvider);
                    ref.invalidate(myTripsProvider);
                    router.go(AppRoutes.login);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.errorBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.errorBorder,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppIcons.logOut(),
                        const SizedBox(width: 8),
                        Text(
                          'Log Out',
                          style: AppText.ui(
                            14,
                            FontWeight.w700,
                            color: AppColors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
  final String icon, label, sub;
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
