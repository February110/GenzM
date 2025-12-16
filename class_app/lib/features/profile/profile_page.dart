import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/config/app_config.dart';
import '../../core/widgets/primary_button.dart';
import '../auth/auth_controller.dart';
import 'profile_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileControllerProvider);
    final notifier = ref.read(profileControllerProvider.notifier);
    final auth = ref.read(authControllerProvider.notifier);

    final nameController = TextEditingController(text: state.user?.name ?? '');
    final avatarController = TextEditingController(
      text: state.user?.avatar ?? '',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ'),
        actions: [
          TextButton(
            onPressed: () {
              auth.logout();
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/', (route) => false);
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: _AvatarView(
                name: state.user?.name,
                avatarUrl: state.user?.avatar,
                radius: 40,
              ),
            ),
            const SizedBox(height: 16),
            if (state.user != null) ...[
              Text('Email: ${state.user!.email}'),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Họ tên'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: avatarController,
              decoration: const InputDecoration(
                labelText: 'Avatar URL (tùy chọn)',
              ),
            ),
            const SizedBox(height: 20),
            if (state.errorMessage != null) ...[
              Text(
                state.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 8),
            ],
            PrimaryButton(
              label: 'Lưu',
              isLoading: state.isLoading,
              onPressed: () async {
                await notifier.update(
                  fullName: nameController.text.trim().isEmpty
                      ? null
                      : nameController.text.trim(),
                  avatar: avatarController.text.trim().isEmpty
                      ? null
                      : avatarController.text.trim(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarView extends StatelessWidget {
  const _AvatarView({this.name, this.avatarUrl, this.radius = 40});

  final String? name;
  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final full = avatarUrl ?? '';
    final resolved = AppConfig.resolveAssetUrl(full);
    final isSvg = AppConfig.isSvgUrl(resolved);
    final hasAvatar = resolved.isNotEmpty;
    final initial =
        (name != null && name!.isNotEmpty) ? name![0].toUpperCase() : '👤';

    if (hasAvatar && isSvg) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFE0ECFF),
        child: ClipOval(
          child: SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: SvgPicture.network(
              resolved,
              fit: BoxFit.cover,
              placeholderBuilder: (_) => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE0ECFF),
      backgroundImage: hasAvatar ? NetworkImage(resolved) : null,
      child: hasAvatar
          ? null
          : Text(
              initial,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Color(0xFF2563EB),
              ),
            ),
    );
  }
}
