import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/login_page.dart';
import '../../features/auth/signup_page.dart';
import '../../features/classrooms/classrooms_page.dart';
import '../../features/home/home_shell_page.dart';

class AppRoute {
  static const String login = '/';
  static const String home = '/home';
  static const String classrooms = '/classrooms';
  static const String signup = '/signup';
}

class AppRouter {
  Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoute.login:
        return MaterialPageRoute<void>(builder: (_) => const LoginPage());
      case AppRoute.signup:
        return MaterialPageRoute<void>(builder: (_) => const SignUpPage());
      case AppRoute.home:
        return MaterialPageRoute<void>(builder: (_) => const HomeShellPage());
      case AppRoute.classrooms:
        return MaterialPageRoute<void>(builder: (_) => const ClassroomsPage());
      default:
        return MaterialPageRoute<void>(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Route not found'))),
        );
    }
  }
}

final appRouterProvider = Provider<AppRouter>((_) => AppRouter());
