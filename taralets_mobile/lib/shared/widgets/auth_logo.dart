import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class AuthLogo extends StatefulWidget {
  const AuthLogo({super.key, required this.emoji, this.size = 100});

  final String emoji;
  final double size;

  @override
  State<AuthLogo> createState() => _AuthLogoState();
}

class _AuthLogoState extends State<AuthLogo> with TickerProviderStateMixin {
  late final AnimationController _enter =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..forward();
  late final AnimationController _float =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
        ..repeat(reverse: true);
  late final Animation<double> _scale =
      CurvedAnimation(parent: _enter, curve: Curves.elasticOut);
  late final Animation<double> _bob =
      CurvedAnimation(parent: _float, curve: Curves.easeInOut);

  @override
  void dispose() {
    _enter.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: AnimatedBuilder(
        animation: _bob,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -7 * _bob.value),
          child: child,
        ),
        child: Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.orangeSoft,
            borderRadius: BorderRadius.circular(widget.size * 0.26),
            boxShadow: const [
              BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 12)),
            ],
          ),
          child: Text(widget.emoji, style: TextStyle(fontSize: widget.size * 0.5)),
        ),
      ),
    );
  }
}