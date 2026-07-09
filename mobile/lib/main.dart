import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_strings.dart';
import 'core/network/dio_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth_profile/providers/auth_notifier.dart';

void main() {
  runApp(
    ProviderScope(
      overrides: [
        // Nối interceptor 401 của Dio với AuthNotifier (xóa phiên -> về Login)
        sessionExpiredHandlerProvider.overrideWith(
          (ref) => () => ref.read(authNotifierProvider.notifier).sessionExpired(),
        ),
      ],
      child: const AporaApp(),
    ),
  );
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
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
