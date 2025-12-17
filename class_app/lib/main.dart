import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(); // đọc .env (hoặc .env.* nếu chỉ định qua DOTENV_FILE)
  runApp(const ProviderScope(child: App()));
}
