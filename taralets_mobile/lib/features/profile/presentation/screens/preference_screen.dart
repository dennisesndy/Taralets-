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

class PreferenceScreen extends ConsumerStatefulWidget {
  final String email;
  const PreferenceScreen({super.key, required this.email});

  @override
  ConsumerState<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends ConsumerState<PreferenceScreen>
    with SingleTickerProviderStateMixin {
  // ---- Options (values are sent to the backend, so keep the strings as-is) ----
  final List<String> _activityOptions = ['Cultural', 'Historical', 'Food', 'Cafe', 'Nature', 'Nightlife'];
  final List<String> _dietaryOptions = ['None', 'Halal', 'Vegan', 'Budget-Friendly'];
  final List<String> _paceOptions = ['Relaxed', 'Moderate', 'Action-Packed', 'Wheelchair Accessible'];
  final List<String> _passengerOptions = ['Regular', 'Student', 'Senior Citizen', 'PWD'];

  // ---- Display-only extras ----
  static const Map<String, String> _activityEmoji = {
    'Cultural': '🎭',
    'Historical': '🏛️',
    'Food': '🍜',
    'Cafe': '☕',
    'Nature': '🌿',
    'Nightlife': '🌃',
  };
  static const Map<String, String> _dietaryEmoji = {
    'None': '🍽️',
    'Halal': '🥙',
    'Vegan': '🥗',
    'Budget-Friendly': '💸',
  };
  static const Map<String, String> _paceEmoji = {
    'Relaxed': '🐢',
    'Moderate': '🚶',
    'Action-Packed': '⚡',
    'Wheelchair Accessible': '♿',
  };
  static const Map<String, String> _paceDesc = {
    'Relaxed': 'Slow and easy, with plenty of breaks',
    'Moderate': 'A balanced mix of stops and rest',
    'Action-Packed': 'More stops, make the most of the day',
    'Wheelchair Accessible': 'Step-free routes and short walking distances',
  };
  static const Map<String, String> _passengerEmoji = {
    'Regular': '🧑',
    'Student': '🎓',
    'Senior Citizen': '🧓',
    'PWD': '♿',
  };
  static const List<double> _budgetPresets = [500, 1000, 2500, 5000, 10000];

  // ---- State ----
  final List<String> _selectedActivities = [];
  final List<String> _selectedDietary = [];
  String _selectedPace = 'Moderate';
  String _selectedPassenger = 'Regular';
  double _maxBudget = 1000.0;

  bool _isLoading = false;
  bool _tagError = false;
  bool _touchedBudget = false;
  bool _touchedPace = false;
  bool _touchedPassenger = false;

  final GlobalKey _tagsKey = GlobalKey();
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Logic
  // ---------------------------------------------------------------------------
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
      await dio.post('${ApiEndpoints.apiPrefix}/profile/preferences', data: {
        "email": widget.email,
        "activity_tags": _selectedActivities,
        "dietary_preferences": _selectedDietary.isEmpty ? ["None"] : _selectedDietary,
        "max_budget": _maxBudget,
        "preferred_pace": _selectedPace,
        "passenger_type": _selectedPassenger
      });

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        context.go(AppRoutes.login);
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Preferences saved! You can now log in.',
                style: TextStyle(color: Colors.white)),
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
          backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
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
        // "None" can't be combined with other restrictions.
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
    p += 0.4 * (math.min(_selectedActivities.length, 2) / 2);
    if (_selectedDietary.isNotEmpty) p += 0.15;
    if (_touchedBudget) p += 0.15;
    if (_touchedPace) p += 0.15;
    if (_touchedPassenger) p += 0.15;
    return p.clamp(0.0, 1.0).toDouble();
  }

  String get _budgetTier {
    if (_maxBudget <= 1000) return 'Budget-savvy';
    if (_maxBudget <= 3000) return 'Comfortable';
    if (_maxBudget <= 6000) return 'Flexible';
    return 'Splurge-ready';
  }

  String _peso(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '₱$buf';
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
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
                        style: AppText.ui(26, FontWeight.w900, color: AppColors.navy),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 250),
                      child: Text(
                        'Tell us how you like to explore so we can build your perfect itinerary.',
                        textAlign: TextAlign.center,
                        style: AppText.ui(14, FontWeight.w400, color: AppColors.muted),
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
                    const SizedBox(height: 16),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 550),
                      child: _budgetSection(),
                    ),
                    const SizedBox(height: 16),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 650),
                      child: _paceSection(),
                    ),
                    const SizedBox(height: 16),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 750),
                      child: _passengerSection(),
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
          BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('Personalization',
                    style: AppText.ui(12, FontWeight.w700, color: AppColors.navy)),
                const Spacer(),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: _progress),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Text(
                    '${(v * 100).round()}%',
                    style: AppText.ui(12, FontWeight.w800, color: AppColors.orange),
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
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
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

  // ---- Sections ----
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
      decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: ok
                ? Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.check_circle_rounded, size: 14, color: badgeFg),
                  )
                : const SizedBox.shrink(),
          ),
          Text('$count selected', style: AppText.ui(12, FontWeight.w800, color: badgeFg)),
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
        subtitle: 'Pick at least 2 interests. These shape your recommendations.',
        trailing: badge,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _activityOptions
              .map((tag) => _SelectChip(
                    emoji: _activityEmoji[tag],
                    label: tag,
                    selected: _selectedActivities.contains(tag),
                    onTap: () => _toggleActivity(tag),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _dietarySection() {
    return _SectionCard(
      emoji: '🍴',
      title: 'Dietary & dining',
      subtitle: "A strict rule. We'll skip food spots that don't fit your needs.",
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _dietaryOptions
            .map((tag) => _SelectChip(
                  emoji: _dietaryEmoji[tag],
                  label: tag,
                  selected: _selectedDietary.contains(tag),
                  onTap: () => _toggleDietary(tag),
                ))
            .toList(),
      ),
    );
  }

  Widget _budgetSection() {
    return _SectionCard(
      emoji: '💰',
      title: 'Spending budget',
      subtitle: 'Your maximum spend per trip, in pesos.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: _maxBudget),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(
              _peso(v.round()),
              textAlign: TextAlign.center,
              style: AppText.ui(36, FontWeight.w900, color: AppColors.orange),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              _budgetTier,
              key: ValueKey(_budgetTier),
              textAlign: TextAlign.center,
              style: AppText.ui(13, FontWeight.w700, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 8,
              activeTrackColor: AppColors.orange,
              inactiveTrackColor: AppColors.border,
              thumbColor: AppColors.orange,
              overlayColor: AppColors.orangeSoft,
              activeTickMarkColor: Colors.transparent,
              inactiveTickMarkColor: Colors.transparent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12, elevation: 3),
            ),
            child: Slider(
              value: _maxBudget,
              min: 500,
              max: 10000,
              divisions: 19,
              onChanged: (val) {
                if (val != _maxBudget) HapticFeedback.selectionClick();
                setState(() {
                  _maxBudget = val;
                  _touchedBudget = true;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('₱500', style: AppText.ui(11, FontWeight.w600, color: AppColors.muted)),
                Text('₱10,000', style: AppText.ui(11, FontWeight.w600, color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _budgetPresets
                .map((v) => _SelectChip(
                      label: _peso(v.toInt()),
                      selected: _maxBudget == v,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _maxBudget = v;
                          _touchedBudget = true;
                        });
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          const _InfoNote(
            icon: Icons.groups_rounded,
            text: "In a group, the lowest budget becomes the ceiling. It can stretch by up to "
                "20% only when few options are left.",
          ),
        ],
      ),
    );
  }

  Widget _paceSection() {
    return _SectionCard(
      emoji: '🚶',
      title: 'Pace & walking',
      subtitle: 'A strict filter so every stop suits how your group likes to move.',
      child: Column(
        children: _paceOptions
            .map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OptionCard(
                    emoji: _paceEmoji[p] ?? '📍',
                    title: p,
                    subtitle: _paceDesc[p] ?? '',
                    selected: _selectedPace == p,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedPace = p;
                        _touchedPace = true;
                      });
                    },
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _passengerSection() {
    final hasDiscount = _selectedPassenger != 'Regular';

    return _SectionCard(
      emoji: '🎫',
      title: 'Passenger type',
      subtitle: 'Used for commute fare estimates.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final w = (c.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _passengerOptions
                    .map((p) => SizedBox(
                          width: w,
                          child: _PassengerTile(
                            emoji: _passengerEmoji[p] ?? '🧑',
                            label: p,
                            discount: p != 'Regular',
                            selected: _selectedPassenger == p,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedPassenger = p;
                                _touchedPassenger = true;
                              });
                            },
                          ),
                        ))
                    .toList(),
              );
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: hasDiscount
                ? const Padding(
                    padding: EdgeInsets.only(top: 14),
                    child: _InfoNote(
                      icon: Icons.local_offer_rounded,
                      text: 'A 20% fare discount will be applied to your public transport estimates.',
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Reusable pieces (private to this screen)
// =============================================================================

/// Shrinks slightly while pressed for tactile feedback.
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
          BoxShadow(color: Color(0x14000000), blurRadius: 28, offset: Offset(0, 12)),
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
                    Text(title, style: AppText.ui(16, FontWeight.w900, color: AppColors.navy)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: AppText.ui(12, FontWeight.w400, color: AppColors.muted)),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
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
              ? const [BoxShadow(color: AppColors.orangeSoft, blurRadius: 10, spreadRadius: 2)]
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
                      child: Icon(Icons.check_rounded, size: 16, color: Colors.white),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.orangeSoft : AppColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.orange : AppColors.border,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedScale(
                scale: selected ? 1.18 : 1.0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.ui(14, FontWeight.w800, color: AppColors.navy)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppText.ui(12, FontWeight.w400, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.orange : Colors.white,
                border: Border.all(
                  color: selected ? AppColors.orange : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        key: ValueKey('on'), size: 16, color: Colors.white)
                    : const SizedBox.shrink(key: ValueKey('off')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PassengerTile extends StatelessWidget {
  const _PassengerTile({
    required this.emoji,
    required this.label,
    required this.discount,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool discount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.orangeSoft : AppColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.orange : AppColors.border,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: Text(emoji, style: const TextStyle(fontSize: 30)),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppText.ui(13, FontWeight.w800, color: AppColors.navy),
            ),
            const SizedBox(height: 6),
            if (discount)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: selected ? AppColors.orange : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.orange),
                ),
                child: Text(
                  '20% OFF',
                  style: AppText.ui(
                    10,
                    FontWeight.w800,
                    color: selected ? Colors.white : AppColors.orange,
                  ),
                ),
              )
            else
              Text(
                'Standard fare',
                style: AppText.ui(11, FontWeight.w500, color: AppColors.muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppText.ui(12, FontWeight.w500, color: AppColors.muted)),
          ),
        ],
      ),
    );
  }
}