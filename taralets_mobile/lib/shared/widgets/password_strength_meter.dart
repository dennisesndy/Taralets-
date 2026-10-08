import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text.dart';

/// Strength bar + requirement checklist + live "passwords match" row.
/// Purely visual: it never blocks submission.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({
    super.key,
    required this.password,
    required this.confirm,
  });

  final String password;
  final String confirm;

  // Swap these for your own semantic colors if AppColors has them.
  static const _weak = Color(0xFFEF4444);
  static const _fair = Color(0xFFF59E0B);
  static const _good = Color(0xFF84CC16);
  static const _strong = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    final checks = <String, bool>{
      '8+ characters': password.length >= 8,
      'Upper & lowercase': RegExp(r'[a-z]').hasMatch(password) &&
          RegExp(r'[A-Z]').hasMatch(password),
      'A number': RegExp(r'\d').hasMatch(password),
      'A symbol': RegExp(r'[^A-Za-z0-9]').hasMatch(password),
    };
    final score = checks.values.where((v) => v).length;
    final colors = [_weak, _weak, _fair, _good, _strong];
    final labels = ['Weak', 'Weak', 'Fair', 'Good', 'Strong'];
    final color = colors[score];
    final filled = math.max(score, 1);

    final showStrength = password.isNotEmpty;
    final showMatch = confirm.isNotEmpty;
    final match = password == confirm;

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: (!showStrength && !showMatch)
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showStrength) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              for (var i = 0; i < 4; i++)
                                Expanded(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    height: 5,
                                    margin: EdgeInsets.only(
                                        right: i < 3 ? 6 : 0),
                                    decoration: BoxDecoration(
                                      color:
                                          i < filled ? color : AppColors.border,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          labels[score],
                          style: AppText.ui(12, FontWeight.w800, color: color),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        for (final e in checks.entries)
                          _RuleChip(label: e.key, ok: e.value),
                      ],
                    ),
                  ],
                  if (showMatch) ...[
                    if (showStrength) const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          match ? Icons.check_circle : Icons.cancel,
                          size: 15,
                          color: match ? _strong : _weak,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          match ? 'Passwords match' : 'Passwords don\'t match yet',
                          style: AppText.ui(12, FontWeight.w600,
                              color: match ? _strong : _weak),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({required this.label, required this.ok});
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            key: ValueKey(ok),
            size: 14,
            color: ok ? PasswordStrengthMeter._strong : AppColors.muted,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppText.ui(
            11.5,
            FontWeight.w600,
            color: ok ? AppColors.navy : AppColors.muted,
          ),
        ),
      ],
    );
  }
}