import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../shared/widgets/auth_backdrop.dart';
import '../../../../shared/widgets/auth_logo.dart';
import '../../../../shared/widgets/back_button_tile.dart';
import '../../../../shared/widgets/fade_slide_in.dart';
import '../../../../shared/widgets/taralets_button.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String email;
  const OtpScreen({super.key, required this.email});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _pinController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyOtp() async {
    final pin = _pinController.text;
    if (pin.length < 6) return;

    setState(() => _isLoading = true);

    try {
      final dio = ref.read(dioProvider);

      // Ipadala ang OTP sa FastAPI para ma-verify
      await dio.post('${ApiEndpoints.apiPrefix}/auth/verify', data: {
        "email": widget.email,
        "otp_code": pin
      });

      if (mounted) {
          context.go(AppRoutes.preferences, extra: widget.email);        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Email verified! You can now log in.',
                style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data['detail'] ?? 'Invalid or expired OTP';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg.toString(), style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _pinController.clear();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
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
                    const Center(child: AuthLogo(emoji: '✉️', size: 84)),
                    const SizedBox(height: 24),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 150),
                      child: Text(
                        'Verify Email',
                        textAlign: TextAlign.center,
                        style: AppText.ui(26, FontWeight.w900, color: AppColors.navy),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 250),
                      child: Text.rich(
                        textAlign: TextAlign.center,
                        TextSpan(
                          style: AppText.ui(14, FontWeight.w400, color: AppColors.muted),
                          children: [
                            const TextSpan(text: "We sent a 6-digit code to "),
                            TextSpan(
                              text: widget.email,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                            const TextSpan(text: ". Please enter it below."),
                          ],
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
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final pinWidth =
                                    ((constraints.maxWidth - 40) / 6).floorToDouble().clamp(38.0, 52.0);

                                final defaultPinTheme = PinTheme(
                                  width: pinWidth,
                                  height: 58,
                                  textStyle: AppText.ui(22, FontWeight.w800, color: AppColors.navy),
                                  decoration: BoxDecoration(
                                    color: AppColors.bg,
                                    border: Border.all(color: AppColors.border),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                );

                                return Pinput(
                                  length: 6,
                                  controller: _pinController,
                                  showCursor: true,
                                  pinAnimationType: PinAnimationType.scale,
                                  animationDuration: const Duration(milliseconds: 160),
                                  defaultPinTheme: defaultPinTheme,
                                  focusedPinTheme: defaultPinTheme.copyDecorationWith(
                                    color: Colors.white,
                                    border: Border.all(color: AppColors.orange, width: 2),
                                  ),
                                  submittedPinTheme: defaultPinTheme.copyDecorationWith(
                                    color: AppColors.orangeSoft,
                                    border: Border.all(color: AppColors.orange),
                                  ),
                                  onCompleted: (pin) => _verifyOtp(),
                                );
                              },
                            ),
                            const SizedBox(height: 28),
                            TaraletsButton.orange(
                              label: 'Verify Code',
                              isLoading: _isLoading,
                              onPressed: _verifyOtp,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 550),
                      child: Text(
                        "Can't find it? Check your spam folder.",
                        textAlign: TextAlign.center,
                        style: AppText.ui(12, FontWeight.w500, color: AppColors.muted),
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