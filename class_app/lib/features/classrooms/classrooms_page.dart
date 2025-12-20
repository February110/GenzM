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
    final state = ref.watch(classroomControllerProvider);
    final mode = state.filterMode;
    final filtered = _filterClassrooms(state.items, state.searchQuery, mode);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
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
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text('Tham gia lớp'),
          content: TextField(
            controller: codeController,
            decoration: const InputDecoration(
              labelText: 'Mã mời',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Tham gia'),
            ),
          ],
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
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text('Tạo lớp mới'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên lớp',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Mô tả (tuỳ chọn)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Tạo'),
            ),
          ],
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
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
}

class ClassroomDetailPage extends ConsumerWidget {
  const ClassroomDetailPage({super.key, required this.classroomId});

  final String classroomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            backgroundColor: const Color(0xFFF6F6F8),
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  pinned: true,
                  floating: false,
                  snap: false,
                  elevation: 0,
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.white,
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
                      color: Colors.white,
                      child: TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        indicatorColor: const Color(0xFF135BEC),
                        labelColor: const Color(0xFF135BEC),
                        unselectedLabelColor: const Color(0xFF6B7280),
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
