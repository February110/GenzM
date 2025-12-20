import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/notification_hub_service.dart';
import '../../../data/models/classroom_model.dart';
import '../../../data/models/assignment_model.dart';
import '../../../data/models/classroom_detail_model.dart';
import '../../classrooms/classroom_controller.dart';
import '../../classrooms/classrooms_page.dart'
    show ClassroomDetailPage, ClassroomsPage;
import '../../../data/repositories/classroom_repository_impl.dart';
import '../../../data/repositories/assignment_repository_impl.dart';
import '../../assignments/submission_status_provider.dart';
import '../../notifications/notifications_controller.dart';
import '../../notifications/notifications_page.dart';
import '../../profile/profile_controller.dart';
import '../../profile/profile_page.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(classroomControllerProvider.notifier).fetchClassrooms(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = ref.watch(classroomControllerProvider);
    final profile = ref.watch(profileControllerProvider);
    final hubStatus = ref.watch(notificationHubManagerProvider);
    final notifications = ref.watch(notificationsControllerProvider);
    final classes = state.items;
    final totalTeaching =
        classes.where((c) => (c.role ?? '').toLowerCase().contains('teacher')).length;
    final totalLearning =
        classes.where((c) => (c.role ?? '').toLowerCase().contains('student')).length;
    final upcomingAsync = ref.watch(upcomingAssignmentsProvider);
    final submissionsAsync = ref.watch(mySubmissionsProvider);
    final submissions = submissionsAsync.valueOrNull;
    final submittedCount = submissions?.length;

    if (profile.user != null && hubStatus == HubStatus.disconnected) {
      Future.microtask(
        () => ref.read(notificationHubManagerProvider.notifier).ensureStarted(),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: colorScheme.primary,
          onRefresh: () =>
              Future.wait([
                ref.read(classroomControllerProvider.notifier).fetchClassrooms(),
                ref.refresh(upcomingAssignmentsProvider.future),
              ]),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: _HeaderCard(
                    isLoading: state.isLoading || profile.isLoading,
                    name: profile.user?.name ?? 'bạn',
                    avatarUrl: profile.user?.avatar,
                    onAvatarTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProfilePage()),
                      );
                    },
                    unreadCount: notifications.unread,
                    onBellTap: () async {
                      if (hubStatus == HubStatus.disconnected) {
                        await ref
                            .read(notificationHubManagerProvider.notifier)
                            .ensureStarted();
                        if (!context.mounted) return;
                      }
                      await ref
                          .read(notificationsControllerProvider.notifier)
                          .load();
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationsPage(),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _StatsRow(
                    submittedCount: submittedCount,
                    totalTeaching: totalTeaching,
                    totalLearning: totalLearning,
                    isLoading: state.isLoading || submissionsAsync.isLoading,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lớp học của tôi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ClassroomsPage(),
                            ),
                          );
                        },
                        child: const Text('Xem tất cả'),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 210,
                  child: state.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : classes.isEmpty
                      ? Center(
                          child: Text(
                            'Chưa có lớp nào, hãy tham gia hoặc tạo lớp.',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: classes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (_, index) {
                            final cls = classes[index];
                            return _ClassCardHorizontal(
                              cls: cls,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ClassroomDetailPage(
                                      classroomId: cls.id,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Nhiệm vụ sắp tới',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: upcomingAsync.when(
                    loading: () => const _TaskPlaceholder(),
                    error: (e, _) => const _TaskPlaceholder(),
                    data: (items) {
                      if (items.isEmpty) return const _TaskPlaceholder();
                      return Column(
                        children: items
                            .map((t) => _TaskCard(task: t))
                            .toList(),
                      );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 90)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.isLoading,
    required this.name,
    this.avatarUrl,
    required this.onAvatarTap,
    required this.onBellTap,
    this.unreadCount = 0,
  });

  final bool isLoading;
  final String name;
  final String? avatarUrl;
  final VoidCallback onAvatarTap;
  final VoidCallback onBellTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: _AvatarCircle(name: name, avatarUrl: avatarUrl, radius: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chào buổi sáng, $name!',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isLoading
                      ? 'Đang tải lớp học...'
                      : 'Chúc bạn một ngày học tập hiệu quả',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onBellTap,
                icon: Icon(
                  Icons.notifications_none,
                  color: colorScheme.onSurface,
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE11D48),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.name, required this.avatarUrl, this.radius = 24});

  final String name;
  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolved = AppConfig.resolveAssetUrl(avatarUrl ?? '');
    final isSvg = AppConfig.isSvgUrl(resolved);
    final hasAvatar = resolved.isNotEmpty;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '👤';

    if (hasAvatar && isSvg) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: colorScheme.primaryContainer,
        child: ClipOval(
          child: SvgPicture.network(
            resolved,
            fit: BoxFit.cover,
            placeholderBuilder: (_) =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.primaryContainer,
      backgroundImage: hasAvatar ? NetworkImage(resolved) : null,
      child: hasAvatar
          ? null
          : Text(
              initial,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.submittedCount,
    required this.totalTeaching,
    required this.totalLearning,
    this.isLoading = false,
  });

  final int? submittedCount;
  final int totalTeaching;
  final int totalLearning;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          label: 'Lớp giảng dạy',
          value: '$totalTeaching',
          icon: Icons.menu_book_outlined,
          color: const Color(0xFF7C3AED),
          isLoading: isLoading,
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'Lớp đang học',
          value: '$totalLearning',
          icon: Icons.school_outlined,
          color: const Color(0xFF0EA5E9),
          isLoading: isLoading,
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'Bài tập đã nộp',
          value: submittedCount == null ? '—' : '$submittedCount',
          icon: Icons.assignment_turned_in_outlined,
          color: const Color(0xFF10B981),
          isLoading: isLoading,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isLoading = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(minHeight: 120),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            isLoading
                ? SizedBox(
                    height: 18,
                    width: 36,
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      color: colorScheme.primary.withValues(alpha: 0.4),
                      backgroundColor: colorScheme.surfaceVariant,
                    ),
                  )
                : Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassCardHorizontal extends StatelessWidget {
  const _ClassCardHorizontal({required this.cls, required this.onTap});

  final ClassroomModel cls;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BannerThumb(bannerUrl: cls.bannerUrl),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Text(
                cls.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                cls.section ?? cls.description ?? 'Giáo viên: —',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerThumb extends StatelessWidget {
  const _BannerThumb({this.bannerUrl});

  final String? bannerUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final url = AppConfig.resolveAssetUrl(bannerUrl);
    final isSvg = AppConfig.isSvgUrl(bannerUrl ?? url);
    final hasBanner = url.isNotEmpty;
    const fallbackAsset = 'assets/images/banners/banner-1.svg';

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(color: colorScheme.surfaceVariant),
            ),
            if (hasBanner && !isSvg)
              Positioned.fill(
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      SvgPicture.asset(fallbackAsset, fit: BoxFit.cover),
                ),
              ),
            if (hasBanner && isSvg)
              Positioned.fill(
                child: SvgPicture.network(
                  url,
                  fit: BoxFit.cover,
                  placeholderBuilder: (_) => const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  semanticsLabel: 'banner',
                ),
              ),
            if (!hasBanner)
              Positioned.fill(
                child: SvgPicture.asset(fallbackAsset, fit: BoxFit.cover),
              ),
            Container(color: colorScheme.onSurface.withValues(alpha: 0.04)),
          ],
        ),
      ),
    );
  }
}

class _TaskPlaceholder extends StatelessWidget {
  const _TaskPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.hourglass_empty, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Chưa có nhiệm vụ sắp tới nào.',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class UpcomingTask {
  UpcomingTask({
    required this.assignment,
    required this.classroom,
  });

  final AssignmentModel assignment;
  final ClassroomModel classroom;
}

final upcomingAssignmentsProvider =
    FutureProvider.autoDispose<List<UpcomingTask>>((ref) async {
      final classroomRepo = ref.read(classroomRepositoryProvider);
      final assignmentRepo = ref.read(assignmentRepositoryProvider);
      final userId = ref.read(profileControllerProvider).user?.id;

      final classes = await classroomRepo.getClassrooms();
      final eligible = <ClassroomModel>[];
      for (final c in classes) {
        final role = (c.role ?? '').toLowerCase();
        final isStudent = role.contains('student') ||
            role.contains('member') ||
            role.isEmpty;
        if (!isStudent && userId != null) {
          try {
            final detail = await classroomRepo.getClassroomDetail(c.id);
            final member = detail.members.firstWhere(
              (m) => m.userId == userId,
              orElse: () => const ClassroomMember(userId: '', role: ''),
            );
            final mRole = (member.role ?? '').toLowerCase();
            if (mRole.contains('student') || mRole.contains('member')) {
              eligible.add(c);
            }
          } catch (_) {}
        } else if (isStudent) {
          eligible.add(c);
        }
      }

      final now = DateTime.now();
      final limit = now.add(const Duration(days: 7));
      final items = <UpcomingTask>[];
      for (final c in eligible) {
        final list = await assignmentRepo.listByClassroom(c.id);
        for (final a in list) {
          if (a.dueAt == null) continue;
          final due = a.dueAt!.toLocal();
          if (due.isAfter(now) && due.isBefore(limit)) {
            items.add(UpcomingTask(assignment: a, classroom: c));
          }
        }
      }

      items.sort((a, b) => a.assignment.dueAt!
          .compareTo(b.assignment.dueAt!));

      return items.take(5).toList();
    });

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final UpcomingTask task;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final due = task.assignment.dueAt?.toLocal();
    final dueText = due != null
        ? DateFormat('HH:mm dd/MM').format(due)
        : 'Chưa có hạn';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.assignment_outlined,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.assignment.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.classroom.name,
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Hạn: $dueText',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
