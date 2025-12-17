import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

final permissionServiceProvider = Provider((_) => PermissionService());

class PermissionService {
  static bool _requested = false;

  Future<void> requestEssentialPermissions() async {
    if (_requested) return;
    _requested = true;

    final permissions = <Permission>[
      Permission.notification,
      Permission.camera,
      Permission.microphone,
    ];

    for (final permission in permissions) {
      final status = await permission.status;
      if (!status.isGranted) {
        await permission.request();
      }
    }
  }
}
