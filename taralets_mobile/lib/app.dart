import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/constants/app_theme.dart';

class TaraletsApp extends ConsumerWidget {
  const TaraletsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Taralets',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light, // Figma is light-only
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
