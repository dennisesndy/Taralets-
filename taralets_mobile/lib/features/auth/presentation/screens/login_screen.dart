import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/auth_backdrop.dart';
import '../../../../shared/widgets/auth_logo.dart';
import '../../../../shared/widgets/fade_slide_in.dart';
import '../../../../shared/widgets/taralets_button.dart';
import '../../../../shared/widgets/taralets_text_field.dart';
import '../../../../repositories/auth_repository.dart';
import '../../../../repositories/repository_providers.dart';
import '../../../profile/data/profile_preferences_repository.dart';
import '../../../profile/providers/preferences_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      _toast('Enter your email and password.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      await ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);

      ref.invalidate(currentUserProvider);
      ref.invalidate(myTripsProvider);

      // Load preferences agad pagka-login
      try {
        final prefs = await ref
            .read(profilePreferencesRepoProvider)
            .getPreferences();
        if (prefs != null) {
          ref
              .read(userPreferencesProvider.notifier)
              .setPreferences(
                activityTags: List<String>.from(prefs['activity_tags'] ?? []),
                dietary: List<String>.from(prefs['dietary_preferences'] ?? []),
              );
        }
      } catch (e) {
        debugPrint('Failed to load preferences: $e');
      }

      if (mounted) context.go(AppRoutes.home);
    } on AuthException catch (e) {
      _toast(e.message);
    } on DioException catch (e) {
      final detail = _detailOf(e);
      if (e.response?.statusCode == 403 &&
          detail.toLowerCase().contains('verif')) {
        if (mounted) context.push(AppRoutes.otp, extra: email);
      } else {
        _toast(detail.isNotEmpty ? detail : 'Login failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _detailOf(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      if (d is String) return d;
      if (d is List && d.isNotEmpty && d.first is Map) {
        return (d.first['msg'] ?? '').toString().replaceFirst(
          'Value error, ',
          '',
        );
      }
    }
    switch (e.type) {
      case DioExceptionType.connectionError:
        return "Can't reach the server. Is the backend running?";
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The server is taking too long. Please try again.';
      default:
        return '';
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AuthBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AuthLogo(emoji: '✈️', size: 100)),
                    const SizedBox(height: 28),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 150),
                      child: Text(
                        'Welcome to Taralets!',
                        textAlign: TextAlign.center,
                        style: AppText.ui(
                          26,
                          FontWeight.w900,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 250),
                      child: Text(
                        'Log in to plan your next group trip.',
                        textAlign: TextAlign.center,
                        style: AppText.ui(
                          14,
                          FontWeight.w400,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 350),
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
                              label: 'Password',
                              controller: _passCtrl,
                              hint: 'Enter your password',
                              icon: Icons.lock_outline_rounded,
                              isPassword: true,
                              textInputAction: TextInputAction.done,
                            ),
                            const SizedBox(height: 26),
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () =>
                                    context.push(AppRoutes.forgotPassword),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    top: 12,
                                    bottom: 24,
                                  ),
                                  child: Text(
                                    'Forgot Password?',
                                    style: AppText.ui(
                                      13,
                                      FontWeight.w700,
                                      color: AppColors.orange,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            TaraletsButton.orange(
                              label: 'Log In',
                              isLoading: _isLoading,
                              onPressed: _login,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 550),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: AppText.ui(
                              13,
                              FontWeight.w500,
                              color: AppColors.muted,
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => context.push(AppRoutes.register),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Sign Up',
                                style: AppText.ui(
                                  13,
                                  FontWeight.w800,
                                  color: AppColors.orange,
                                ),
                              ),
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
        ),
      ),
    );
  }
}
