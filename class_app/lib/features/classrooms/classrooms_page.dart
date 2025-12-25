import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/classroom_detail_model.dart';
import '../../data/models/classroom_model.dart';
import '../assignments/assignments_page.dart';
import 'models/classrooms_state.dart';
import '../meetings/meetings_page.dart';
import '../profile/profile_controller.dart';
import 'classroom_controller.dart';
import 'classroom_detail_provider.dart';
import 'classroom_widgets.dart';
import 'feed_tab.dart';
import 'grades_tab.dart';

class ClassroomsPage extends ConsumerStatefulWidget {
  const ClassroomsPage({super.key});

  @override
  ConsumerState<ClassroomsPage> createState() => _ClassroomsPageState();
}

List<ClassroomModel> _filterClassrooms(
  List<ClassroomModel> items,
  String query,
  ClassFilterMode? mode,
) {
  final q = query.trim().toLowerCase();
  final safeMode = mode ?? ClassFilterMode.all;

  final filteredByMode = items.where((c) {
    final role = (c.role ?? '').toLowerCase();
    if (safeMode == ClassFilterMode.teaching) {
      return role.contains('teacher');
    }
    if (safeMode == ClassFilterMode.enrolled) {
      return role.contains('student');
    }
    return true;
  }).toList();

  if (q.isEmpty) return filteredByMode;

  return filteredByMode.where((c) {
    final name = c.name.toLowerCase();
    final section = c.section?.toLowerCase() ?? '';
    final invite = c.inviteCode?.toLowerCase() ?? '';
    return name.contains(q) || section.contains(q) || invite.contains(q);
  }).toList();
}

class _ClassroomsPageState extends ConsumerState<ClassroomsPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      ref
          .read(classroomControllerProvider.notifier)
          .setSearchQuery(_searchController.text);
    });
    Future<void>.microtask(
      () => ref.read(classroomControllerProvider.notifier).fetchClassrooms(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(classroomControllerProvider);
    final mode = state.filterMode;
    final filtered = _filterClassrooms(state.items, state.searchQuery, mode);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2563EB),
        onPressed: _showActionsSheet,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF2563EB),
        onRefresh: () =>
            ref.read(classroomControllerProvider.notifier).fetchClassrooms(),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 205,
              elevation: 0,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              clipBehavior: Clip.none,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                background: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(40)),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            const SizedBox(height: 10),
                            const Text(
                              'Lớp học của tôi',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Quản lý và tham gia các lớp học',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 15),
                            _SearchBar(
                              controller: _searchController,
                              hint: 'Tìm lớp học...',
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _FilterPill(
                                  label: 'Tất cả',
                                  selected: mode == ClassFilterMode.all,
                                  onTap: () => ref
                                      .read(classroomControllerProvider.notifier)
                                      .setFilter(ClassFilterMode.all),
                                ),
                                const SizedBox(width: 8),
                                _FilterPill(
                                  label: 'Giảng dạy',
                                  selected: mode == ClassFilterMode.teaching,
                                  onTap: () => ref
                                      .read(classroomControllerProvider.notifier)
                                      .setFilter(ClassFilterMode.teaching),
                                ),
                                const SizedBox(width: 8),
                                _FilterPill(
                                  label: 'Tham gia',
                                  selected: mode == ClassFilterMode.enrolled,
                                  onTap: () => ref
                                      .read(classroomControllerProvider.notifier)
                                      .setFilter(ClassFilterMode.enrolled),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 15)),

            if (state.isLoading && state.items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.errorMessage != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ErrorView(
                    message: state.errorMessage!,
                    onRetry: () => ref
                        .read(classroomControllerProvider.notifier)
                        .fetchClassrooms(),
                  ),
                ),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: EmptyState(onCreate: _showCreateDialog),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 240,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final classroom = filtered[index];
                    return ClassCard(
                      classroom: classroom,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ClassroomDetailPage(classroomId: classroom.id),
                          ),
                        );
                      },
                    );
                  }, childCount: filtered.length),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }

  Future<void> _showJoinDialog() async {
    final codeController = TextEditingController();
    final notifier = ref.read(classroomControllerProvider.notifier);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: codeController,
          builder: (context, value, _) {
            final canSubmit = value.text.trim().isNotEmpty;
            return _ClassroomActionDialog(
              icon: Icons.login_rounded,
              title: 'Tham gia lớp học',
              subtitle: 'Nhập mã mời do giáo viên cung cấp.',
              primaryLabel: 'Tham gia',
              isPrimaryEnabled: canSubmit,
              onPrimary: () => Navigator.pop(context, true),
              onCancel: () => Navigator.pop(context, false),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: codeController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    decoration: _dialogInputDecoration(
                      context,
                      label: 'Mã lớp',
                      hint: 'VD: 8X2KQ',
                      icon: Icons.key_rounded,
                    ),
                    style: const TextStyle(
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                    onSubmitted: (_) {
                      if (canSubmit) {
                        Navigator.pop(context, true);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mã có thể gồm chữ và số.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == true && codeController.text.isNotEmpty) {
      try {
        await notifier.joinClassroom(codeController.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tham gia lớp thành công')),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
    }
  }

  Future<void> _showCreateDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final notifier = ref.read(classroomControllerProvider.notifier);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: nameController,
          builder: (context, value, _) {
            final canSubmit = value.text.trim().isNotEmpty;
            return _ClassroomActionDialog(
              icon: Icons.add_circle_rounded,
              title: 'Tạo lớp mới',
              subtitle: 'Tạo không gian học tập và mời học viên tham gia.',
              primaryLabel: 'Tạo lớp',
              isPrimaryEnabled: canSubmit,
              onPrimary: () => Navigator.pop(context, true),
              onCancel: () => Navigator.pop(context, false),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: _dialogInputDecoration(
                      context,
                      label: 'Tên lớp',
                      hint: 'VD: Toán 12A1',
                      icon: Icons.class_,
                    ),
                    onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _dialogInputDecoration(
                      context,
                      label: 'Mô tả (tuỳ chọn)',
                      hint: 'VD: Lịch học thứ 2, 4, 6',
                      icon: Icons.notes_rounded,
                    ),
                    maxLines: 2,
                    onSubmitted: (_) {
                      if (canSubmit) {
                        Navigator.pop(context, true);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Bạn có thể chỉnh sửa thông tin lớp sau khi tạo.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == true && nameController.text.isNotEmpty) {
      try {
        final newClass = await notifier.createClassroom(
          name: nameController.text.trim(),
          description: descController.text.trim().isEmpty
              ? null
              : descController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tạo lớp ${newClass.name} thành công')),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
    }
  }

  void _showActionsSheet() {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.login, color: Color(0xFF2563EB)),
                title: const Text('Tham gia lớp bằng mã mời'),
                onTap: () {
                  Navigator.pop(context);
                  _showJoinDialog();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.add_circle_outline,
                  color: Color(0xFF2563EB),
                ),
                title: const Text('Tạo lớp mới'),
                onTap: () {
                  Navigator.pop(context);
                  _showCreateDialog();
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  InputDecoration _dialogInputDecoration(
    BuildContext context, {
    required String label,
    String? hint,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      prefixIconColor: colorScheme.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}

class ClassroomDetailPage extends ConsumerWidget {
  const ClassroomDetailPage({super.key, required this.classroomId});

  final String classroomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profile = ref.watch(profileControllerProvider);
    final detailAsync = ref.watch(classroomDetailProvider(classroomId));

    return detailAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) =>
          Scaffold(body: Center(child: Text(error.toString()))),
      data: (detail) {
        final teacherName =
            detail.members
                .firstWhere(
                  (m) => (m.role ?? '').toLowerCase() == 'teacher',
                  orElse: () => detail.members.isNotEmpty
                      ? detail.members.first
                      : const ClassroomMember(
                          userId: '',
                          fullName: 'Giáo viên',
                        ),
                )
                .fullName ??
            'Giáo viên';
        final currentUserId = profile.user?.id;
        final isTeacher = detail.members.any(
          (m) =>
              m.userId == currentUserId &&
              (m.role ?? '').toLowerCase() == 'teacher',
        );
        final tabs = <Tab>[
          const Tab(text: 'Bảng tin'),
          const Tab(text: 'Bài tập trên lớp'),
          const Tab(text: 'Cuộc họp'),
          const Tab(text: 'Mọi người'),
        ];
        if (isTeacher) {
          tabs.add(const Tab(text: 'Điểm'));
        }

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  pinned: true,
                  floating: false,
                  snap: false,
                  elevation: 0,
                  backgroundColor: colorScheme.surface,
                  surfaceTintColor: colorScheme.surface,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  title: const Text(
                    'Chi tiết lớp học',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  centerTitle: true,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {},
                    ),
                  ],
                ),

                // Banner + teacher row
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      children: [
                        ClassBanner(detail: detail),
                        TeacherRow(
                          teacherName: teacherName,
                          inviteCode: detail.inviteCode,
                        ),
                      ],
                    ),
                  ),
                ),

                // TabBar pin
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarHeaderDelegate(
                    child: Container(
                      color: colorScheme.surface,
                      child: TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        indicatorColor: colorScheme.primary,
                        labelColor: colorScheme.primary,
                        unselectedLabelColor: colorScheme.onSurfaceVariant,
                        indicatorSize: TabBarIndicatorSize.label,
                        tabs: tabs,
                      ),
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  FeedTab(detail: detail, classroomId: classroomId),
                  AssignmentsPage(classroomId: classroomId),
                  MeetingsPage(
                    classroomId: classroomId,
                    isTeacher: isTeacher,
                  ),
                  MembersList(members: detail.members),
                  if (isTeacher)
                    GradesTab(
                      classroomId: classroomId,
                      assignments: detail.assignments,
                    ),
                ].where((_) => true).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  _TabBarHeaderDelegate({required this.child});
  final Widget child;

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _TabBarHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: true,
                  fillColor: Colors.transparent,
                ),
              ),
            ),
            Icon(Icons.search, color: Colors.white.withValues(alpha: 0.0)),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          border: Border.all(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ClassroomActionDialog extends StatelessWidget {
  const _ClassroomActionDialog({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onCancel,
    required this.isPrimaryEnabled,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onCancel;
  final bool isPrimaryEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.18),
                      colorScheme.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border(
                    bottom: BorderSide(color: theme.dividerColor),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: child,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onCancel,
                        child: const Text('Hủy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: isPrimaryEnabled ? onPrimary : null,
                        child: Text(primaryLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
