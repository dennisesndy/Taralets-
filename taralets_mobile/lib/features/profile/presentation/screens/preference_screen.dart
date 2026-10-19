import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../shared/widgets/auth_backdrop.dart';
import '../../../../shared/widgets/auth_logo.dart';
import '../../../../shared/widgets/fade_slide_in.dart';
import '../../../../shared/widgets/taralets_button.dart';
import '../../data/profile_preferences_repository.dart';
import '../../providers/preferences_provider.dart';

class PreferenceScreen extends ConsumerStatefulWidget {
  final String? returnRoute;
  final Object? returnExtra;

  const PreferenceScreen({super.key, this.returnRoute, this.returnExtra});

  @override
  ConsumerState<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends ConsumerState<PreferenceScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _activityOptions = [
    'Accommodations',
    'Cafes',
    'Desserts / Bakeries',
    'Restaurant / Eatery',
    'Museums',
    'Church / Religious Site',
    'Parks / Plazas',
    'Historical / Tourist Site',
    'Shopping / Retail',
    'Health / Wellness',
    'Entertainment / Leisure',
    'Nightlife / Bars',
    'Government / Services',
    'Others',
  ];

  final List<String> _dietaryOptions = [
    'None',
    'Halal',
    'Vegan',
    'Budget-Friendly',
  ];

  static const Map<String, String> _activityEmoji = {
    'Accommodations': '🏨',
    'Cafes': '☕',
    'Desserts / Bakeries': '🧁',
    'Restaurant / Eatery': '🍽️',
    'Museums': '🏛️',
    'Church / Religious Site': '⛪',
    'Parks / Plazas': '🌳',
    'Historical / Tourist Site': '🗺️',
    'Shopping / Retail': '🛍️',
    'Health / Wellness': '💆',
    'Entertainment / Leisure': '🎡',
    'Nightlife / Bars': '🍸',
    'Government / Services': '🏢',
    'Others': '📍',
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
  bool _isInitializing = true;
  bool _isOnboardingFlow = false;
  bool _hasSavedPreferences = false;
  bool _isEditing = true;
  bool _tagError = false;

  double _maxBudget = 2500.0;
  String _preferredPace = 'Moderate';
  String _passengerType = 'Regular';
  List<String> _accessibilityPreferences = [];

  final GlobalKey _tagsKey = GlobalKey();

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void initState() {
    super.initState();
    _initializePreferences();
  }

  Future<void> _initializePreferences() async {
    try {
      final storage = ref.read(secureStorageProvider);
      final onboardingToken = await storage.getOnboardingToken();

      if (!mounted) return;

      // Registration: show the initial preferences setup.
      if (onboardingToken != null && onboardingToken.trim().isNotEmpty) {
        setState(() {
          _isOnboardingFlow = true;
          _isEditing = true;
          _isInitializing = false;
        });
        return;
      }

      // Profile: fetch the logged-in user's saved preferences.
      final repository = ref.read(profilePreferencesRepoProvider);
      final preferences = await repository.getPreferences();

      if (!mounted) return;

      if (preferences != null) {
        final activities = List<String>.from(
          preferences['activity_tags'] ?? [],
        );

        final dietary = List<String>.from(
          preferences['dietary_preferences'] ?? [],
        );

        setState(() {
          _selectedActivities
            ..clear()
            ..addAll(activities);

          _selectedDietary
            ..clear()
            ..addAll(dietary);

          _maxBudget =
              (preferences['max_budget'] as num?)?.toDouble() ?? 2500.0;

          _preferredPace =
              preferences['preferred_pace'] as String? ?? 'Moderate';

          _passengerType =
              preferences['passenger_type'] as String? ?? 'Regular';

          _accessibilityPreferences = List<String>.from(
            preferences['accessibility_preferences'] ?? [],
          );

          _hasSavedPreferences = true;
          _isEditing = false;
          _isInitializing = false;
        });

        ref
            .read(userPreferencesProvider.notifier)
            .setPreferences(
              activityTags: activities,
              dietary: dietary.isEmpty ? ['None'] : dietary,
            );
      } else {
        // Logged-in user with no saved preferences yet.
        setState(() {
          _hasSavedPreferences = false;
          _isEditing = true;
          _isInitializing = false;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;

      setState(() {
        _isEditing = true;
        _isInitializing = false;
      });

      _toast(_errorText(e, 'Failed to load preferences'));
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isEditing = true;
        _isInitializing = false;
      });

      _toast('Failed to load preferences: $e');
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else if (widget.returnRoute != null) {
      context.go(widget.returnRoute!, extra: widget.returnExtra);
    } else {
      // Fallback for navigation stacks without a previous screen.
      context.go(AppRoutes.login);
    }
  }

  Future<void> _savePreferences() async {
    if (_isLoading || _isInitializing) return;

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
      final dietaryToSave = _selectedDietary.isEmpty
          ? ['None']
          : List<String>.from(_selectedDietary);

      final repository = ref.read(profilePreferencesRepoProvider);
      final storage = ref.read(secureStorageProvider);

      if (_isOnboardingFlow) {
        // Registration: use the temporary onboarding token.
        await repository.saveOnboardingPreferences(
          activityTags: _selectedActivities,
          dietaryPreferences: dietaryToSave,
          maxBudget: _maxBudget,
          preferredPace: _preferredPace,
          passengerType: _passengerType,
          accessibilityPreferences: _accessibilityPreferences,
        );

        // Delete the temporary token only after a successful save.
        await storage.deleteOnboardingToken();

        if (!mounted) return;

        _toast('Preferences saved! You can now log in.', isError: false);

        context.go(AppRoutes.login);
        return;
      }

      // Profile: update preferences using the normal access token.
      await repository.savePreferences(
        activityTags: _selectedActivities,
        dietaryPreferences: dietaryToSave,
        maxBudget: _maxBudget,
        preferredPace: _preferredPace,
        passengerType: _passengerType,
        accessibilityPreferences: _accessibilityPreferences,
      );

      ref
          .read(userPreferencesProvider.notifier)
          .setPreferences(
            activityTags: _selectedActivities,
            dietary: dietaryToSave,
          );

      if (!mounted) return;

      setState(() {
        _selectedDietary
          ..clear()
          ..addAll(dietaryToSave);

        _hasSavedPreferences = true;
        _isEditing = false;
        _tagError = false;
      });

      // Show success only after the API confirms the save.
      _toast('Preferences updated successfully!', isError: false);
    } on DioException catch (e) {
      if (mounted) {
        _toast(_errorText(e, 'Failed to save preferences'));
      }
    } catch (e) {
      if (mounted) {
        _toast('Failed to save preferences: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _errorText(DioException e, String fallback) {
    final data = e.response?.data;

    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];

      if (detail is String) return detail;

      if (detail is List && detail.isNotEmpty && detail.first is Map) {
        return (detail.first['msg'] ?? fallback).toString();
      }
    }

    if (e.type == DioExceptionType.connectionError) {
      return "Can't reach the server. Is the backend running?";
    }

    if (e.response?.statusCode == 401) {
      return 'Your session may have expired. Please log in again.';
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
    if (!_isEditing) return;

    HapticFeedback.selectionClick();

    setState(() {
      if (_selectedActivities.contains(tag)) {
        _selectedActivities.remove(tag);
      } else {
        _selectedActivities.add(tag);
      }

      if (_selectedActivities.length >= 2) {
        _tagError = false;
      }
    });
  }

  void _toggleDietary(String tag) {
    if (!_isEditing) return;

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
    var progress = 0.0;
    progress += 0.6 * (math.min(_selectedActivities.length, 2) / 2);

    if (_selectedDietary.isNotEmpty) {
      progress += 0.4;
    }

    return progress.clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.orange)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      bottomNavigationBar: _buildBottomBar(),
      body: AuthBackdrop(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Back button.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: _goBack,
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.navy,
                          size: 26,
                        ),
                        tooltip: 'Go back',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                        _isOnboardingFlow
                            ? 'Tell us what you like to explore and your dietary preferences.'
                            : _isEditing
                            ? 'Update your interests and dining preferences.'
                            : 'Your saved travel preferences.',
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
    final bool isReadOnly =
        !_isOnboardingFlow && _hasSavedPreferences && !_isEditing;

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
                  isReadOnly ? 'Your Preferences' : 'Personalization',
                  style: AppText.ui(12, FontWeight.w700, color: AppColors.navy),
                ),
                const Spacer(),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: _progress),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Text(
                    '${(value * 100).round()}%',
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
              builder: (context, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: AppColors.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.orange,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (isReadOnly)
              TaraletsButton.orange(
                label: 'Edit Preferences',
                isLoading: _isLoading,
                onPressed: () {
                  setState(() => _isEditing = true);
                },
              )
            else
              TaraletsButton.orange(
                label: _isOnboardingFlow ? 'Save Preferences' : 'Save Changes',
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
    final isValid = count >= 2;

    final Color badgeBackground = isValid
        ? Colors.green.shade50
        : (_tagError ? Colors.red.shade50 : AppColors.orangeSoft);

    final Color badgeForeground = isValid
        ? Colors.green.shade700
        : (_tagError ? Colors.red.shade700 : AppColors.orange);

    final badge = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: isValid
                ? Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: badgeForeground,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Text(
            '$count selected',
            style: AppText.ui(12, FontWeight.w800, color: badgeForeground),
          ),
        ],
      ),
    );

    return AnimatedBuilder(
      key: _tagsKey,
      animation: _shake,
      builder: (context, child) {
        final value = _shake.value;
        final dx = math.sin(value * math.pi * 6) * 10 * (1 - value);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: _SectionCard(
        emoji: '🎯',
        title: 'What do you enjoy?',
        subtitle: _isEditing
            ? 'Pick at least 2 interests. These will be your default activities for trips.'
            : 'These are your saved default activities for trips.',
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
      subtitle: _isEditing
          ? 'Set your default dining restrictions. You can still modify these per trip.'
          : 'These are your saved default dining preferences.',
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
