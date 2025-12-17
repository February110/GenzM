import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../data/models/assignment_model.dart';
import '../../../data/models/classroom_model.dart';
import '../../../data/models/classroom_detail_model.dart';
import '../../../data/repositories/assignment_repository_impl.dart';
import '../../../data/repositories/classroom_repository_impl.dart';
import '../../profile/profile_controller.dart';

class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(calendarAssignmentsProvider);
    final classesAsync = ref.watch(calendarClassroomsProvider);
    final selectedClassId = ref.watch(selectedCalendarClassIdProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Lịch nộp bài',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      backgroundColor: const Color(0xFFF5F7FB),
      body: RefreshIndicator(
        color: const Color(0xFF2563EB),
        onRefresh: () async {
          ref.invalidate(calendarAssignmentsProvider);
          ref.invalidate(calendarClassroomsProvider);
          await ref.read(calendarAssignmentsProvider.future);
        },
        child: scheduleAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Không tải được lịch: $error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
          data: (items) {
            final filteredItems = selectedClassId == null
                ? items
                : items.where((i) => i.classroomId == selectedClassId).toList();

            final grouped = _groupByDate(filteredItems);
            final dates = grouped.keys.toList()..sort();

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              itemCount: dates.isEmpty ? 1 : dates.length + 1,
              itemBuilder: (_, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        classesAsync.when(
                          data: (classes) => _ClassFilterButton(
                            selected: selectedClassId,
                            classes: classes,
                            onSelect: (value) {
                              ref
                                  .read(selectedCalendarClassIdProvider.notifier)
                                  .state = value;
                              ref.invalidate(calendarAssignmentsProvider);
                            },
                          ),
                          loading: () => const SizedBox(
                            height: 48,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (e, _) => const SizedBox.shrink(),
                        ),
                        if (dates.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(
                              child: Text(
                                'Chưa có bài tập sắp tới',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }

                final day = dates[index - 1];
                final assignments = grouped[day]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        _formatDate(day),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    ...assignments.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ScheduleCard(item: item),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

final calendarAssignmentsProvider =
    FutureProvider.autoDispose<List<CalendarItem>>((ref) async {
      await initializeDateFormatting('vi');
      final classroomRepo = ref.read(classroomRepositoryProvider);
      final assignmentRepo = ref.read(assignmentRepositoryProvider);
      final userId = ref.read(profileControllerProvider).user?.id;
      final selectedId = ref.watch(selectedCalendarClassIdProvider);

      // Luôn lấy mới danh sách lớp để có assignment mới nhất
      final classrooms = await classroomRepo.getClassrooms();
      final filteredClassrooms = <ClassroomModel>[];
      for (final c in classrooms) {
        final isSelected = selectedId == null || c.id == selectedId;
        if (!isSelected) continue;

        final role = (c.role ?? '').toLowerCase();
        var isTeacher = role.contains('teacher');
        var isStudent = role.contains('student') || role.contains('member');

        // Nếu role trống, fallback kiểm tra theo members trong detail
        if (!isTeacher && !isStudent && userId != null) {
          try {
            final detail = await classroomRepo.getClassroomDetail(c.id);
            final member = detail.members.firstWhere(
              (m) => m.userId == userId,
              orElse: () => const ClassroomMember(userId: ''),
            );
            final mRole = (member.role ?? '').toLowerCase();
            isTeacher = mRole.contains('teacher');
            isStudent = mRole.contains('student') || mRole.contains('member');
          } catch (_) {}
        }

        if (!isTeacher && isStudent) {
          filteredClassrooms.add(c);
        }
      }
      final items = <CalendarItem>[];

      for (final c in filteredClassrooms) {
        final assignments = await assignmentRepo.listByClassroom(c.id);
        for (final a in assignments) {
          final dueAt = a.dueAt;
          if (dueAt == null) continue;
          final dueLocal = dueAt.toLocal();
          items.add(
            CalendarItem(
              classroomId: c.id,
              assignment: a,
              dueLocal: dueLocal,
              classroomName: c.name,
            ),
          );
        }
      }

      items.sort((a, b) => a.assignment.dueAt!.compareTo(b.assignment.dueAt!));
      return items;
    });

final calendarClassroomsProvider =
    FutureProvider.autoDispose<List<ClassroomModel>>((ref) async {
      final repo = ref.read(classroomRepositoryProvider);
      final userId = ref.read(profileControllerProvider).user?.id;
      final classes = await repo.getClassrooms();
      final filtered = <ClassroomModel>[];
      for (final c in classes) {
        final role = (c.role ?? '').toLowerCase();
        var isTeacher = role.contains('teacher');
        var isStudent = role.contains('student') || role.contains('member');

        if (!isTeacher && !isStudent && userId != null) {
          try {
            final detail = await repo.getClassroomDetail(c.id);
            final member = detail.members.firstWhere(
              (m) => m.userId == userId,
              orElse: () => const ClassroomMember(userId: ''),
            );
            final mRole = (member.role ?? '').toLowerCase();
            isStudent = mRole.contains('student') || mRole.contains('member');
          } catch (_) {}
        }

        if (!isTeacher && isStudent) {
          filtered.add(c);
        }
      }
      return filtered;
    });

final selectedCalendarClassIdProvider = StateProvider<String?>((ref) => null);

class CalendarItem {
  CalendarItem({
    required this.classroomId,
    required this.assignment,
    required this.dueLocal,
    required this.classroomName,
  });
  final String classroomId;
  final String classroomName;
  final AssignmentModel assignment;
  final DateTime dueLocal;
}

Map<DateTime, List<CalendarItem>> _groupByDate(List<CalendarItem> items) {
  final map = <DateTime, List<CalendarItem>>{};
  for (final item in items) {
    final due = item.dueLocal;
    final key = DateTime(due.year, due.month, due.day);
    map.putIfAbsent(key, () => []).add(item);
  }
  return map;
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final todayKey = DateTime(now.year, now.month, now.day);
  final key = DateTime(date.year, date.month, date.day);
  final df = DateFormat('EEEE, dd/MM', 'vi');
  if (key == todayKey) return 'Hôm nay · ${df.format(date)}';
  if (key == todayKey.add(const Duration(days: 1))) {
    return 'Ngày mai · ${df.format(date)}';
  }
  return df.format(date);
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.item});
  final CalendarItem item;

  @override
  Widget build(BuildContext context) {
    final a = item.assignment;
    final due = item.dueLocal;
    final isOverdue = due.isBefore(DateTime.now());
    final timeStr = DateFormat('HH:mm dd/MM').format(due);
    final color = isOverdue ? const Color(0xFFF43F5E) : const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5EDFF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.classroomName,
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.access_time, size: 16, color: color),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  a.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if ((a.instructions ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    a.instructions!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4B5563),
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassFilterButton extends StatelessWidget {
  const _ClassFilterButton({
    required this.selected,
    required this.classes,
    required this.onSelect,
  });

  final String? selected;
  final List<ClassroomModel> classes;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ClassroomModel? selectedClass;
    if (selected != null) {
      for (final c in classes) {
        if (c.id == selected) {
          selectedClass = c;
          break;
        }
      }
    }
    final selectedName = selectedClass?.name ?? 'Tất cả các lớp';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.filter_alt_rounded, color: Color(0xFF2563EB)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
          ],
        ),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    if (classes.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.filter_alt_rounded, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Text(
                      'Chọn lớp',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('Tất cả các lớp'),
                  leading: const Icon(Icons.all_inclusive),
                  trailing:
                      selected == null ? const Icon(Icons.check, color: Color(0xFF2563EB)) : null,
                  onTap: () {
                    onSelect(null);
                    Navigator.pop(context);
                  },
                ),
                ...classes.map(
                  (c) => ListTile(
                    title: Text(c.name),
                    trailing: selected == c.id
                        ? const Icon(Icons.check, color: Color(0xFF2563EB))
                        : null,
                    onTap: () {
                      onSelect(c.id);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
