import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/config/app_config.dart';
import '../auth/auth_controller.dart';
import 'profile_controller.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _avatarController;
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(profileControllerProvider).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _avatarController = TextEditingController(text: user?.avatar ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(profileControllerProvider, (prev, next) {
      if (prev?.user != next.user && next.user != null) {
        _nameController.text = next.user!.name ?? '';
        _avatarController.text = next.user!.avatar ?? '';
      }
    });

    final state = ref.watch(profileControllerProvider);
    final notifier = ref.read(profileControllerProvider.notifier);
    final auth = ref.read(authControllerProvider.notifier);
    final user = state.user;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Hồ sơ cá nhân',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: state.isLoading
                ? null
                : () async {
                    await notifier.update(
                      fullName: _nameController.text.trim().isEmpty
                          ? null
                          : _nameController.text.trim(),
                      avatar: _avatarController.text.trim().isEmpty
                          ? null
                          : _avatarController.text.trim(),
                    );
                  },
            child: const Text('Lưu'),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        _AvatarView(
                          name: user?.name,
                          avatarUrl: user?.avatar,
                          radius: 48,
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () => _showAvatarDialog(context),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF2563EB),
                              ),
                              child: const Icon(
                                Icons.camera_alt_outlined,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.name ?? 'Người dùng',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _sectionTitle('Thông tin chung'),
              const SizedBox(height: 10),
              _InfoCard(
                children: [
                  _FieldTile(
                    label: 'Họ tên',
                    trailing: SizedBox(
                      width: 190,
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: 'Nhập họ tên',
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  _FieldTile(
                    label: 'Email',
                    trailing: Text(
                      user?.email ?? '—',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  _FieldTile(
                    label: 'SDT',
                    trailing: Text(
                      'Chưa cập nhật',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Email được quản lý bởi nhà trường và không thể thay đổi.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _sectionTitle('Cài đặt tài khoản'),
              const SizedBox(height: 10),
              _InfoCard(
                children: [
                  SwitchListTile(
                    value: _darkMode,
                    onChanged: (v) => setState(() => _darkMode = v),
                    activeColor: const Color(0xFF2563EB),
                    title: const Text(
                      'Chế độ tối',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lock_outline, color: Color(0xFF2563EB)),
                    title: const Text(
                      'Đổi mật khẩu',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.language_outlined, color: Color(0xFF2563EB)),
                    title: const Text(
                      'Ngôn ngữ',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    trailing: const Text(
                      'Tiếng Việt',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: () {
                  auth.logout();
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Đăng xuất',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Phiên bản 2.4.0 (Build 1024)',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 12,
                  ),
                ),
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAvatarDialog(BuildContext context) {
    final controller = TextEditingController(text: _avatarController.text);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cập nhật ảnh đại diện'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Dán URL ảnh...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              _avatarController.text = controller.text.trim();
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _FieldTile extends StatelessWidget {
  const _FieldTile({required this.label, required this.trailing});

  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

Widget _sectionTitle(String title) {
  return Text(
    title.toUpperCase(),
    style: const TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: 12,
      color: Color(0xFF94A3B8),
      letterSpacing: 0.4,
    ),
  );
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
