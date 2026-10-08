import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../../../shared/widgets/taralets_button.dart';
import '../../../../shared/widgets/taralets_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _email = TextEditingController();
  final _shakeKey = GlobalKey<ShakeWidgetState>();
  bool _isLoading = false;
  bool _isValid = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _email.removeListener(_onEmailChanged);
    _email.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    final valid = _emailRegex.hasMatch(_email.text.trim());
    if (valid != _isValid || _error != null) {
      setState(() {
        _isValid = valid;
        _error = null; // clear stale error as soon as they edit
      });
    }
  }

  void _fail(String message) {
    HapticFeedback.mediumImpact();
    setState(() => _error = message);
    _shakeKey.currentState?.shake();
  }

  Future<void> _sendOtp() async {
    final email = _email.text.trim();
    if (!_emailRegex.hasMatch(email)) {
      _fail('Please enter a valid email address.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).forgotPassword(email);
      if (mounted) {
        HapticFeedback.lightImpact();
        // Ipasa ang email sa susunod na screen para hindi na i-type ulit
        context.push(AppRoutes.resetPassword, extra: email);
      }
    } on AuthException catch (e) {
      if (mounted) _fail(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  child: AuthStepper(step: 1, label: 'Verify email'),
                ),
                const SizedBox(height: 28),
                const AuthReveal(
                  delay: Duration(milliseconds: 120),
                  child: FloatingBadge(
                    child: AuthLogo(emoji: '🔐', size: 80),
                  ),
                ),
                const SizedBox(height: 24),
                AuthReveal(
                  delay: const Duration(milliseconds: 180),
                  child: Text(
                    'Forgot Password',
                    textAlign: TextAlign.center,
                    style:
                        AppText.ui(24, FontWeight.w900, color: AppColors.navy),
                  ),
                ),
                const SizedBox(height: 8),
                AuthReveal(
                  delay: const Duration(milliseconds: 240),
                  child: Text(
                    'Enter your email address and we will send you an OTP to reset your password.',
                    textAlign: TextAlign.center,
                    style: AppText.ui(14, FontWeight.w400,
                        color: AppColors.muted, height: 1.5),
                  ),
                ),
                const SizedBox(height: 32),

                AuthReveal(
                  delay: const Duration(milliseconds: 300),
                  child: ShakeWidget(
                    key: _shakeKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TaraletsTextField(
                          label: 'Email Address',
                          controller: _email,
                          hint: 'juan@example.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          alignment: Alignment.topLeft,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _isValid
                                ? Padding(
                                    key: const ValueKey('ok'),
                                    padding: const EdgeInsets.only(
                                        top: 8, left: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle,
                                            size: 15,
                                            color: Color(0xFF16A34A)),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Looks good',
                                          style: AppText.ui(
                                              12, FontWeight.w600,
                                              color: const Color(0xFF16A34A)),
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox(
                                    key: ValueKey('empty'),
                                    width: double.infinity),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                AuthReveal(
                  delay: const Duration(milliseconds: 360),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.orangeSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.mark_email_unread_outlined,
                            size: 18, color: AppColors.orange),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'The code usually arrives within a minute. Check your spam folder if you don\'t see it.',
                            style: AppText.ui(12.5, FontWeight.w500,
                                color: AppColors.navy, height: 1.45),
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
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: (_isValid || _isLoading) ? 1 : 0.55,
                    child: TaraletsButton.orange(
                      label: 'Send OTP',
                      isLoading: _isLoading,
                      onPressed: _sendOtp,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AuthReveal(
                  delay: const Duration(milliseconds: 480),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Remembered it?',
                        style: AppText.ui(13, FontWeight.w500,
                            color: AppColors.muted),
                      ),
                      TextButton(
                        onPressed: () => context.pop(),
                        child: Text(
                          'Back to log in',
                          style: AppText.ui(13, FontWeight.w800,
                              color: AppColors.orange),
                        ),
                      ),
                    ],
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