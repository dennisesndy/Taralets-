import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text.dart';

class TaraletsTextField extends StatefulWidget {
  const TaraletsTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.icon,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final IconData? icon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  @override
  State<TaraletsTextField> createState() => _TaraletsTextFieldState();
}

class _TaraletsTextFieldState extends State<TaraletsTextField> {
  final FocusNode _focus = FocusNode();
  bool _hasFocus = false;
  late bool _obscure = widget.isPassword;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _hasFocus = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  OutlineInputBorder _border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _hasFocus ? AppColors.orange : AppColors.muted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: AppText.ui(
            12,
            FontWeight.w700,
            color: _hasFocus ? AppColors.orange : AppColors.navy,
          ),
          child: Text(widget.label),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _hasFocus ? AppColors.orangeSoft : const Color(0x0A000000),
                blurRadius: _hasFocus ? 16 : 6,
                spreadRadius: _hasFocus ? 3 : 0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            obscureText: _obscure,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            cursorColor: AppColors.orange,
            style: AppText.ui(14, FontWeight.w600, color: AppColors.navy),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.bg,
              hintText: widget.hint,
              hintStyle: AppText.ui(14, FontWeight.w400, color: AppColors.muted),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              prefixIcon: widget.icon == null
                  ? null
                  : TweenAnimationBuilder<Color?>(
                      tween: ColorTween(end: iconColor),
                      duration: const Duration(milliseconds: 200),
                      builder: (context, color, _) =>
                          Icon(widget.icon, size: 20, color: color),
                    ),
              suffixIcon: widget.isPassword
                  ? IconButton(
                      splashRadius: 20,
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          key: ValueKey(_obscure),
                          size: 20,
                          color: AppColors.muted,
                        ),
                      ),
                    )
                  : null,
              border: _border(AppColors.border),
              enabledBorder: _border(AppColors.border),
              focusedBorder: _border(AppColors.orange, 2),
            ),
          ),
        ),
        if (widget.helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              widget.helper!,
              style: AppText.ui(11, FontWeight.w500, color: AppColors.muted),
            ),
          ),
      ],
    );
  }
}