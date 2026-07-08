import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'core/router/app_router.dart';
import 'features/auth_profile/providers/auth_notifier.dart';

void main() {
  runApp(const ProviderScope(child: AporaApp()));
}

class AporaApp extends ConsumerStatefulWidget {
  const AporaApp({super.key});

  @override
  ConsumerState<AporaApp> createState() => _AporaAppState();
}

class _AporaAppState extends ConsumerState<AporaApp> {
  @override
  void initState() {
    super.initState();
    // Khôi phục phiên đăng nhập từ secure storage khi mở app
    Future.microtask(
      () => ref.read(authNotifierProvider.notifier).restoreSession(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
