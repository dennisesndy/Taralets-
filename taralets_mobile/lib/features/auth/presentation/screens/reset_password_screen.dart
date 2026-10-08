import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../repositories/auth_repository.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../../shared/widgets/auth_backdrop.dart';
import '../../../../shared/widgets/auth_logo.dart';
import '../../../../shared/widgets/auth_motion.dart';
import '../../../../shared/widgets/back_button_tile.dart';
import '../../../../shared/widgets/error_note.dart';
import '../../../../shared/widgets/password_strength_meter.dart';
import '../../../../shared/widgets/taralets_button.dart';
import '../../../../shared/widgets/taralets_text_field.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  /// Tumatanggap ng email mula sa nakaraang screen
  const ResetPasswordScreen({super.key, this.email = ''});
  final String email;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  static const _resendSeconds = 30; // match your backend's rate limit
  static const _errorRed = Color(0xFFEF4444);

  final _otpController = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _otpShake = GlobalKey<ShakeWidgetState>();
  final _formShake = GlobalKey<ShakeWidgetState>();

  bool _isLoading = false;
  bool _isResending = false;
  bool _otpError = false;
  String? _error;

  Timer? _timer;
  int _cooldown = _resendSeconds;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    for (final c in [_otpController, _newPassword, _confirmPassword]) {
      c.addListener(_clearErrorOnEdit);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _clearErrorOnEdit() {
    if (_error != null || _otpError) {
      setState(() {
        _error = null;
        _otpError = false;
      });
    }
  }

  void _startCooldown() {
    _timer?.cancel();
    _cooldown = _resendSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  void _fail(String message, {bool otp = false}) {
    HapticFeedback.mediumImpact();
    setState(() {
      _error = message;
      _otpError = otp;
    });
    (otp ? _otpShake : _formShake).currentState?.shake();
  }

  Future<void> _resendCode() async {
    if (_cooldown > 0 || _isResending || widget.email.isEmpty) return;
    setState(() {
      _isResending = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).forgotPassword(widget.email);
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _otpController.clear();
      setState(_startCooldown);
      ScaffoldMessenger.of(context).showSnackBar(_snack('A new code is on its way.'));
    } on AuthException catch (e) {
      if (mounted) _fail(e.message);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_otpController.text.length < 6) {
      _fail('Enter the full 6-digit code.', otp: true);
      return;
    }
    if (_newPassword.text.isEmpty) {
      _fail('Please enter a new password.');
      return;
    }
    if (_newPassword.text != _confirmPassword.text) {
      _fail('Passwords do not match.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
      _otpError = false;
    });

    try {
      await ref.read(authRepositoryProvider).resetPassword(
            widget.email,
            _otpController.text,
            _newPassword.text,
          );

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          _snack('Password reset successful. Please log in.'),
        );
        context.go(AppRoutes.login);
      }
    } on AuthException catch (e) {
      // Karaniwang mali/expired na OTP ang dahilan, kaya i-highlight ang pins
      if (mounted) _fail(e.message, otp: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  SnackBar _snack(String text) => SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(text, style: AppText.ui(13, FontWeight.w600, color: Colors.white)),
      );

  PinTheme _pinTheme(double width) => PinTheme(
        width: width,
        height: 58,
        textStyle: AppText.ui(20, FontWeight.w800, color: AppColors.navy),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final hasEmail = widget.email.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: AuthBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthReveal(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BackButtonTile(onTap: () => context.pop()),
                  ),
                ),
                const SizedBox(height: 20),
                const AuthReveal(
                  delay: Duration(milliseconds: 60),
                  child: AuthStepper(step: 2, label: 'New password'),
                ),
                const SizedBox(height: 24),
                const AuthReveal(
                  delay: Duration(milliseconds: 120),
                  child: FloatingBadge(
                    child: AuthLogo(emoji: '✨', size: 80),
                  ),
                ),
                const SizedBox(height: 24),
                AuthReveal(
                  delay: const Duration(milliseconds: 180),
                  child: Text(
                    'Create New Password',
                    textAlign: TextAlign.center,
                    style:
                        AppText.ui(24, FontWeight.w900, color: AppColors.navy),
                  ),
                ),
                const SizedBox(height: 8),
                AuthReveal(
                  delay: const Duration(milliseconds: 240),
                  child: Column(
                    children: [
                      Text(
                        hasEmail
                            ? 'Enter the 6-digit code we sent to'
                            : 'Enter the 6-digit code sent to your email and set your new password.',
                        textAlign: TextAlign.center,
                        style: AppText.ui(14, FontWeight.w400,
                            color: AppColors.muted, height: 1.5),
                      ),
                      if (hasEmail) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.orangeSoft,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.mail_outline,
                                  size: 15, color: AppColors.orange),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  widget.email,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.ui(13, FontWeight.w700,
                                      color: AppColors.navy),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── OTP ────────────────────────────────────────────
                AuthReveal(
                  delay: const Duration(milliseconds: 300),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '6-Digit OTP Code',
                        style: AppText.ui(12, FontWeight.w700,
                            color: AppColors.navy),
                      ),
                      const SizedBox(height: 8),
                      ShakeWidget(
                        key: _otpShake,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // 6 pins + 5 default gaps (8px) — never overflows
                            final w = ((constraints.maxWidth - 40) / 6)
                                .clamp(38.0, 52.0);
                            final base = _pinTheme(w);
                            return Center(
                              child: Pinput(
                                length: 6,
                                controller: _otpController,
                                autofocus: true,
                                forceErrorState: _otpError,
                                pinAnimationType: PinAnimationType.scale,
                                defaultPinTheme: base,
                                focusedPinTheme: base.copyDecorationWith(
                                  color: Colors.white,
                                  border: Border.all(
                                      color: AppColors.orange, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.orangeSoft,
                                      blurRadius: 16,
                                      spreadRadius: 3,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                submittedPinTheme: base.copyDecorationWith(
                                  color: Colors.white,
                                  border: Border.all(
                                      color: AppColors.navy, width: 1.4),
                                ),
                                errorPinTheme: base.copyDecorationWith(
                                  color: _errorRed.withOpacity(0.06),
                                  border:
                                      Border.all(color: _errorRed, width: 1.6),
                                ),
                                showCursor: true,
                                cursor: Container(
                                    width: 2,
                                    height: 24,
                                    color: AppColors.orange),
                                onCompleted: (_) {
                                  HapticFeedback.selectionClick();
                                  FocusScope.of(context).nextFocus();
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _cooldown > 0
                              ? Padding(
                                  key: const ValueKey('wait'),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  child: Text(
                                    'Resend code in 0:${_cooldown.toString().padLeft(2, '0')}',
                                    style: AppText.ui(13, FontWeight.w600,
                                        color: AppColors.muted),
                                  ),
                                )
                              : TextButton.icon(
                                  key: const ValueKey('resend'),
                                  onPressed: (_isResending || !hasEmail)
                                      ? null
                                      : _resendCode,
                                  icon: _isResending
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.orange),
                                        )
                                      : const Icon(Icons.refresh_rounded,
                                          size: 18, color: AppColors.orange),
                                  label: Text(
                                    'Resend code',
                                    style: AppText.ui(13, FontWeight.w800,
                                        color: AppColors.orange),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Passwords ──────────────────────────────────────
                AuthReveal(
                  delay: const Duration(milliseconds: 360),
                  child: ShakeWidget(
                    key: _formShake,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TaraletsTextField(
                          label: 'New Password',
                          controller: _newPassword,
                          hint: '••••••••',
                          icon: Icons.lock_outline,
                          isPassword: true,
                        ),
                        const SizedBox(height: 16),
                        TaraletsTextField(
                          label: 'Confirm New Password',
                          controller: _confirmPassword,
                          hint: '••••••••',
                          icon: Icons.lock_outline,
                          isPassword: true,
                        ),
                        AnimatedBuilder(
                          animation: Listenable.merge(
                              [_newPassword, _confirmPassword]),
                          builder: (_, __) => PasswordStrengthMeter(
                            password: _newPassword.text,
                            confirm: _confirmPassword.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _error != null
                        ? Padding(
                            key: ValueKey(_error),
                            padding: const EdgeInsets.only(top: 16),
                            child: ErrorNote(title: 'ERROR', message: _error!),
                          )
                        : const SizedBox(
                            key: ValueKey('no-error'), width: double.infinity),
                  ),
                ),

                const SizedBox(height: 28),
                AuthReveal(
                  delay: const Duration(milliseconds: 420),
                  child: TaraletsButton.orange(
                    label: 'Reset Password',
                    isLoading: _isLoading,
                    onPressed: _resetPassword,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}