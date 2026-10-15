import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text.dart';

/// Soft, rounded confirm dialog. Returns `true` when confirmed,
/// `false` when cancelled and `null` when dismissed by tapping outside.
/// Drop-in replacement for `showDialog<bool>(... AlertDialog ...)`.
Future<bool?> showTaraletsConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'No',
  bool destructive = true,
  IconData icon = Icons.help_outline_rounded,
}) {
  final accent = destructive ? AppColors.red : AppColors.primary;
  final accentSoft = destructive ? AppColors.redSoft : AppColors.primarySoft;

  return showDialog<bool>(
    context: context,
    builder: (c) => Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: accentSoft, shape: BoxShape.circle),
              child: Icon(icon, color: accent, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.ui(18, FontWeight.w800, color: AppColors.navy),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.ui(
                13,
                FontWeight.w400,
                color: AppColors.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(c, false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      cancelLabel,
                      style: AppText.ui(
                        14,
                        FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      confirmLabel,
                      style: AppText.ui(
                        14,
                        FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Rounded bottom sheet with a drag handle, for overlays that don't need
/// their own full screen (pickers, filters, quick actions).
Future<T?> showTaraletsSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (c) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(child: builder(c)),
            ],
          ),
        ),
      ),
    ),
  );
}