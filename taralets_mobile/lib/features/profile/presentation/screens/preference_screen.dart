import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/auth_backdrop.dart';
import '../../../../shared/widgets/auth_logo.dart';
import '../../../../shared/widgets/fade_slide_in.dart';
import '../../../../shared/widgets/taralets_button.dart';
import '../../providers/preferences_provider.dart';

class PreferenceScreen extends ConsumerStatefulWidget {
  final String email;
  const PreferenceScreen({super.key, required this.email});

  @override
  ConsumerState<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends ConsumerState<PreferenceScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _activityOptions = [
    "Accommodation",
    "Cafe",
    "Restaurant / Eatery",
    "Museum",
    "Church / Religious Site",
    "Park / Plaza",
    "Historical / Tourist Site",
    "Shop / Retail",
    "Health & Wellness",
    "Entertainment",
    "Recreation & Arts",
    "Community & Events",
  ];

  final List<String> _dietaryOptions = [
    'None',
    'Halal',
    'Vegan',
    'Budget-Friendly',
  ];

  static const Map<String, String> _activityEmoji = {
    "Accommodation": '🏨',
    "Cafe": '☕',
    "Restaurant / Eatery": '🍽️',
    "Museum": '🏛️',
    "Church / Religious Site": '⛪',
    "Park / Plaza": '🌳',
    "Historical / Tourist Site": '🗺️',
    "Shop / Retail": '🛍️',
    "Health & Wellness": '💆',
    "Entertainment": '🎭',
    "Recreation & Arts": '🎨',
    "Community & Events": '🎪',
  };

  static const Map<String, String> _dietaryEmoji = {
    'None': '🍽️',
    'Halal': '🥙',
    'Vegan': '🥗',
    'Budget-Friendly': '💸',
  };

  final List<String> _selectedActivities = [];
  final List<String> _selectedDietary = [];

  bool _isLoading = false;
  bool _tagError = false;

  final GlobalKey _tagsKey = GlobalKey();
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _savePreferences() async {
    if (_selectedActivities.length < 2) {
      setState(() => _tagError = true);
      HapticFeedback.mediumImpact();
      final ctx = _tagsKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          alignment: 0.1,
        );
      }
      _shake.forward(from: 0);
      _toast('Please select at least 2 activity tags');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dio = ref.read(dioProvider);
      final dietaryToSave = _selectedDietary.isEmpty
          ? ['None']
          : _selectedDietary;

      await dio.post(
        '${ApiEndpoints.apiPrefix}/profile/preferences',
        data: {
          'email': widget.email,
          'activity_tags': _selectedActivities,
          'dietary_preferences': dietaryToSave,
          'max_budget': 1000.0,
          'preferred_pace': 'Moderate',
          'passenger_type': 'Regular',
        },
      );

      ref
          .read(userPreferencesProvider.notifier)
          .setPreferences(
            activityTags: _selectedActivities,
            dietary: dietaryToSave,
          );

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        context.go(AppRoutes.login);
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              'Preferences saved! You can now log in.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on DioException catch (e) {
      _toast(_errorText(e, 'Failed to save preferences'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _errorText(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      if (d is String) return d;
      if (d is List && d.isNotEmpty && d.first is Map) {
        return (d.first['msg'] ?? fallback).toString();
      }
    }
    if (e.type == DioExceptionType.connectionError) {
      return "Can't reach the server. Is the backend running?";
    }
    return fallback;
  }

  void _toast(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: isError
              ? Colors.red.shade600
              : Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _toggleActivity(String tag) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedActivities.contains(tag)) {
        _selectedActivities.remove(tag);
      } else {
        _selectedActivities.add(tag);
      }
      if (_selectedActivities.length >= 2) _tagError = false;
    });
  }

  void _toggleDietary(String tag) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedDietary.contains(tag)) {
        _selectedDietary.remove(tag);
      } else if (tag == 'None') {
        _selectedDietary
          ..clear()
          ..add('None');
      } else {
        _selectedDietary
          ..remove('None')
          ..add(tag);
      }
    });
  }

  double get _progress {
    var p = 0.0;
    p += 0.6 * (math.min(_selectedActivities.length, 2) / 2);
    if (_selectedDietary.isNotEmpty) p += 0.4;
    return p.clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: _buildBottomBar(),
      body: AuthBackdrop(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AuthLogo(emoji: '🧭', size: 76)),
                    const SizedBox(height: 18),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 150),
                      child: Text(
                        'Travel Preferences',
                        textAlign: TextAlign.center,
                        style: AppText.ui(
                          26,
                          FontWeight.w900,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 250),
                      child: Text(
                        'Tell us what you like to explore and your dietary preferences.',
                        textAlign: TextAlign.center,
                        style: AppText.ui(
                          14,
                          FontWeight.w400,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 350),
                      child: _tagsSection(),
                    ),
                    const SizedBox(height: 16),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 450),
                      child: _dietarySection(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  'Personalization',
                  style: AppText.ui(12, FontWeight.w700, color: AppColors.navy),
                ),
                const Spacer(),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: _progress),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Text(
                    '${(v * 100).round()}%',
                    style: AppText.ui(
                      12,
                      FontWeight.w800,
                      color: AppColors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: _progress),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.orange,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TaraletsButton.orange(
              label: 'Save Preferences',
              isLoading: _isLoading,
              onPressed: _savePreferences,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tagsSection() {
    final count = _selectedActivities.length;
    final ok = count >= 2;

    final Color badgeBg = ok
        ? Colors.green.shade50
        : (_tagError ? Colors.red.shade50 : AppColors.orangeSoft);
    final Color badgeFg = ok
        ? Colors.green.shade700
        : (_tagError ? Colors.red.shade700 : AppColors.orange);

    final badge = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: ok
                ? Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: badgeFg,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Text(
            '$count selected',
            style: AppText.ui(12, FontWeight.w800, color: badgeFg),
          ),
        ],
      ),
    );

    return AnimatedBuilder(
      key: _tagsKey,
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: _SectionCard(
        emoji: '🎯',
        title: 'What do you enjoy?',
        subtitle:
            'Pick at least 2 interests. These will be your default activities for trips.',
        trailing: badge,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _activityOptions
              .map(
                (tag) => _SelectChip(
                  emoji: _activityEmoji[tag],
                  label: tag,
                  selected: _selectedActivities.contains(tag),
                  onTap: () => _toggleActivity(tag),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _dietarySection() {
    return _SectionCard(
      emoji: '🍽️',
      title: 'Dietary & dining',
      subtitle:
          'Set your default dining restrictions. You can still modify these per trip.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _dietaryOptions
            .map(
              (tag) => _SelectChip(
                emoji: _dietaryEmoji[tag],
                label: tag,
                selected: _selectedDietary.contains(tag),
                onTap: () => _toggleDietary(tag),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Pressable extends StatefulWidget {
  const _Pressable({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.orangeSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.ui(
                        16,
                        FontWeight.w900,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppText.ui(
                        12,
                        FontWeight.w400,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.emoji,
  });

  final String label;
  final String? emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.orange : AppColors.bg,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? AppColors.orange : AppColors.border,
            width: 1.5,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: AppColors.orangeSoft,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
            ],
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: AppText.ui(
                13,
                FontWeight.w700,
                color: selected ? Colors.white : AppColors.navy,
              ),
              child: Text(label),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: selected
                  ? const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
