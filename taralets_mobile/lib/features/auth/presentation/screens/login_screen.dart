import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/widgets/auth_backdrop.dart';
import '../../../../shared/widgets/auth_header.dart';
import '../../../../shared/widgets/fade_slide_in.dart';
import '../../../../shared/widgets/auth_button.dart';
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
    final h = MediaQuery.sizeOf(context).height;
    final headerH = (h * 0.32).clamp(240.0, 320.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: AuthBackdrop(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              children: [
                AuthHeader(height: headerH, logoSize: 92),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 22, 28, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 150),
                            child: Text(
                              'Welcome back!',
                              textAlign: TextAlign.center,
                              style: AppText.ui(26, FontWeight.w900,
                                  color: AppColors.navy),
                            ),
                          ),
                          const SizedBox(height: 6),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 230),
                            child: Text(
                              'Your crew is waiting. Log in to jump back into your trips.',
                              textAlign: TextAlign.center,
                              style: AppText.ui(14, FontWeight.w400,
                                  color: AppColors.muted),
                            ),
                          ),
                          const SizedBox(height: 28),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 320),
                            child: TaraletsTextField(
                              label: 'Email Address',
                              controller: _emailCtrl,
                              hint: 'you@example.com',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 400),
                            child: TaraletsTextField(
                              label: 'Password',
                              controller: _passCtrl,
                              hint: 'Enter your password',
                              icon: Icons.lock_outline_rounded,
                              isPassword: true,
                              textInputAction: TextInputAction.done,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  context.push(AppRoutes.forgotPassword),
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(top: 14, bottom: 24),
                                child: Text(
                                  'Forgot Password?',
                                  style: AppText.ui(13, FontWeight.w700,
                                      color: AppColors.brandOrange),
                                ),
                              ),
                            ),
                          ),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 480),
                            child: AuthButton(
                              label: 'Log In',
                              isLoading: _isLoading,
                              onPressed: _login,
                            ),
                          ),
                          const SizedBox(height: 22),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 560),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'New here? ',
                                  style: AppText.ui(13, FontWeight.w500,
                                      color: AppColors.muted),
                                ),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => context.push(AppRoutes.register),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'Create an account',
                                      style: AppText.ui(13, FontWeight.w800,
                                          color: AppColors.brandOrange),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}