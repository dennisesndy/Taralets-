import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text.dart';

/// Orange call-to-action with a white arrow chip. Same call shape as
/// `TaraletsButton.orange(label:, isLoading:, onPressed:)`.
class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.brandOrange.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        clipBehavior: Clip.antiAlias,
        color: AppColors.brandOrange,
        shape: RoundedRectangleBorder(borderRadius: radius),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label,
                          style: AppText.ui(16, FontWeight.w800, color: Colors.white)),
                      const SizedBox(width: 10),
                      const MintArrowChip(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Small white circle with an orange arrow, used inside orange buttons.
class MintArrowChip extends StatelessWidget {
  const MintArrowChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.brandOrange),
    );
  }
}
