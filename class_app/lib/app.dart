import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_router.dart';
import 'core/theme/app_theme.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.read(appRouterProvider);

    return MaterialApp(
      title: 'Class App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      onGenerateRoute: router.onGenerateRoute,
      initialRoute: AppRoute.login,
    );
  }
}
