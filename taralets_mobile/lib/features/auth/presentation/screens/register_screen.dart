import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../shared/widgets/auth_backdrop.dart';
import '../../../../shared/widgets/back_button_tile.dart';
import '../../../../shared/widgets/fade_slide_in.dart';
import '../../../../shared/widgets/taralets_button.dart';
import '../../../../shared/widgets/taralets_text_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _register() async {
    // Stop here if the two passwords differ. Nothing is sent to the API.
    if (_passCtrl.text != _confirmPasswordController.text) {
      _showError('Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dio = ref.read(dioProvider);

      // Ipadala ang data sa FastAPI
      await dio.post(ApiEndpoints.register, data: {
        "full_name": "${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}",
        "email": _emailCtrl.text.trim(),
        "phone_number": _phoneCtrl.text.trim(),
        "password": _passCtrl.text
      });

      if (mounted) {
        context.push(AppRoutes.otp, extra: _emailCtrl.text.trim());
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data['detail'] ?? 'Registration failed';
      _showError(errorMsg.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Live "match / don't match" hint shown under the confirm field.
  Widget _matchHint() {
    return AnimatedBuilder(
      animation: Listenable.merge([_passCtrl, _confirmPasswordController]),
      builder: (context, _) {
        final confirm = _confirmPasswordController.text;
        final show = confirm.isNotEmpty;
        final match = confirm == _passCtrl.text;
        final color = match ? Colors.green.shade600 : Colors.red.shade600;

        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topLeft,
          child: show
              ? Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Row(
                    children: [
                      Icon(
                        match ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                        size: 15,
                        color: color,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        match ? 'Passwords match' : "Passwords don't match yet",
                        style: AppText.ui(12, FontWeight.w600, color: color),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuthBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeSlideIn(
                      offset: const Offset(-16, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: BackButtonTile(onTap: () => context.pop()),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 120),
                      child: Text(
                        'Create Account',
                        style: AppText.ui(26, FontWeight.w900, color: AppColors.navy),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 220),
                      child: Text(
                        'Enter your details to start planning trips.',
                        style: AppText.ui(13, FontWeight.w400, color: AppColors.muted),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 320),
                      child: Container(
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
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TaraletsTextField(
                                    label: 'First Name',
                                    controller: _firstNameCtrl,
                                    hint: 'Juan',
                                    textInputAction: TextInputAction.next,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TaraletsTextField(
                                    label: 'Last Name',
                                    controller: _lastNameCtrl,
                                    hint: 'Dela Cruz',
                                    textInputAction: TextInputAction.next,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            TaraletsTextField(
                              label: 'Email Address',
                              controller: _emailCtrl,
                              hint: 'you@example.com',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 18),
                            TaraletsTextField(
                              label: 'Phone Number',
                              controller: _phoneCtrl,
                              hint: '09XX XXX XXXX',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 18),
                            TaraletsTextField(
                              label: 'Password',
                              controller: _passCtrl,
                              hint: 'Create a password',
                              helper: 'At least 8 characters, with a letter and a number.',
                              icon: Icons.lock_outline_rounded,
                              isPassword: true,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 18),
                            TaraletsTextField(
                              label: 'Confirm Password',
                              controller: _confirmPasswordController,
                              hint: 'Re-type your password',
                              icon: Icons.lock_outline_rounded,
                              isPassword: true,
                              textInputAction: TextInputAction.done,
                            ),
                            _matchHint(),
                            const SizedBox(height: 26),
                            TaraletsButton.orange(
                              label: 'Sign Up',
                              isLoading: _isLoading,
                              onPressed: _register,
                            ),
                          ],
                        ),
                      ),
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
}