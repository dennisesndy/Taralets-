import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text.dart';

/// Figma `Input`: 13sp/600 label, 14sp text, 12dp radius, 1.5dp #E5E7EB border
/// on a #F7F7F5 fill. Focus turns the border orange with a 3dp 12% ring.
class TaraletsField extends StatefulWidget {
  const TaraletsField({
    super.key,
    this.label,
    required this.hint,
    this.controller,
    this.onChanged,
    this.icon,
    this.height,
    this.radius = 12,
    this.fontSize = 14,
    this.verticalPadding = 13,
  });

  final String? label;
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final Widget? icon;

  /// When set, renders a multi-line box of this height (Figma textarea).
  final double? height;
  final double radius;
  final double fontSize;
  final double verticalPadding;

  @override
  State<TaraletsField> createState() => _TaraletsFieldState();
}

class _TaraletsFieldState extends State<TaraletsField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multi = widget.height != null;
    OutlineInputBorder b(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(widget.radius),
      borderSide: BorderSide(color: c, width: 1.5),
    );

    final field = TextField(
      controller: widget.controller,
      focusNode: _focus,
      onChanged: widget.onChanged,
      expands: multi,
      minLines: multi ? null : 1,
      maxLines: multi ? null : 1,
      textAlignVertical: multi ? TextAlignVertical.top : null,
      cursorColor: AppColors.orange,
      style: AppText.ui(widget.fontSize, FontWeight.w400),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.bg,
        hintText: widget.hint,
        hintStyle: AppText.ui(
          widget.fontSize,
          FontWeight.w400,
          color: AppColors.placeholder,
        ),
        contentPadding: EdgeInsets.fromLTRB(
          widget.icon != null ? 42 : 16,
          multi ? 12 : widget.verticalPadding,
          16,
          multi ? 12 : widget.verticalPadding,
        ),
        border: b(AppColors.border),
        enabledBorder: b(AppColors.border),
        focusedBorder: b(AppColors.orange),
      ),
    );

    Widget box = Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        boxShadow: _focus.hasFocus
            ? [
                BoxShadow(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  spreadRadius: 3,
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          field,
          if (widget.icon != null)
            Positioned(left: 14, child: IgnorePointer(child: widget.icon!)),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null && widget.label!.isNotEmpty) ...[
          Text(widget.label!, style: AppText.ui(13, FontWeight.w600)),
          const SizedBox(height: 6),
        ],
        box,
      ],
    );
  }
}
