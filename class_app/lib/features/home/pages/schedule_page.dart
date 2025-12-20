import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final scheduleAsync = ref.watch(calendarAssignmentsProvider);
    final classesAsync = ref.watch(calendarClassroomsProvider);
    final selectedClassId = ref.watch(selectedCalendarClassIdProvider);
    final selectedDay = ref.watch(selectedCalendarDayProvider);
    final focusedDay = ref.watch(focusedCalendarDayProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
        title: const Text(
          'Lịch nộp bài',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: colorScheme.primary,
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
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          ),
          data: (items) {
            final filteredItems = selectedClassId == null
                ? items
                : items.where((i) => i.classroomId == selectedClassId).toList();

            final grouped = _groupByDate(filteredItems);
            final dates = grouped.keys.toList()..sort();
            final normalizedSelected = _normalize(selectedDay);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                _CalendarCard(
                  focusedDay: focusedDay,
                  selectedDay: normalizedSelected,
                  events: grouped,
                  onDaySelected: (selected, focused) {
                    ref.read(selectedCalendarDayProvider.notifier).state =
                        _normalize(selected);
                    ref.read(focusedCalendarDayProvider.notifier).state = focused;
                  },
                ),
                const SizedBox(height: 12),
                classesAsync.when(
                  data: (classes) => _ClassFilterButton(
                    selected: selectedClassId,
                    classes: classes,
                    onSelect: (value) {
                      ref.read(selectedCalendarClassIdProvider.notifier).state = value;
                      ref.invalidate(calendarAssignmentsProvider);
                    },
                  ),
                  loading: () => const SizedBox(
                    height: 48,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                if (dates.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_available,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Chưa có bài tập sắp tới',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...dates.map(
                    (day) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              _formatDate(day),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          ...grouped[day]!.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ScheduleCard(item: item),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
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
final selectedCalendarDayProvider =
    StateProvider<DateTime>((ref) => DateTime.now());
final focusedCalendarDayProvider =
    StateProvider<DateTime>((ref) => DateTime.now());

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
    final key = _normalize(due);
    map.putIfAbsent(key, () => []).add(item);
  }
  return map;
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final todayKey = DateTime(now.year, now.month, now.day);
  final key = _normalize(date);
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final a = item.assignment;
    final due = item.dueLocal;
    final isOverdue = due.isBefore(DateTime.now());
    final timeStr = DateFormat('HH:mm dd/MM').format(due);
    final color = isOverdue ? colorScheme.error : colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
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
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item.classroomName,
                        style: TextStyle(
                          color: colorScheme.primary,
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                if ((a.instructions ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    a.instructions!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
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

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.focusedDay,
    required this.selectedDay,
    required this.events,
    required this.onDaySelected,
  });

  final DateTime focusedDay;
  final DateTime selectedDay;
  final Map<DateTime, List<CalendarItem>> events;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: SizedBox(
        height: 340,
        child: TableCalendar<CalendarItem>(
          locale: 'vi',
          rowHeight: 42,
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2050, 12, 31),
          focusedDay: focusedDay,
          selectedDayPredicate: (day) => isSameDay(day, selectedDay),
          onDaySelected: onDaySelected,
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: colorScheme.onSurface,
            ),
            leftChevronMargin: EdgeInsets.zero,
            rightChevronMargin: EdgeInsets.zero,
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: TextStyle(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
            weekendStyle: TextStyle(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            markerDecoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            defaultTextStyle: TextStyle(color: colorScheme.onSurface),
            weekendTextStyle: TextStyle(color: colorScheme.onSurfaceVariant),
            outsideTextStyle: TextStyle(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            disabledTextStyle: TextStyle(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            selectedTextStyle: TextStyle(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
            todayTextStyle: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
            markerSizeScale: 0.15,
            markersAlignment: Alignment.bottomCenter,
            markersMaxCount: 3,
            outsideDaysVisible: false,
          ),
          availableGestures: AvailableGestures.horizontalSwipe,
          startingDayOfWeek: StartingDayOfWeek.monday,
          eventLoader: (day) => events[_normalize(day)] ?? const <CalendarItem>[],
        ),
      ),
    );
  }
}

DateTime _normalize(DateTime date) => DateTime(date.year, date.month, date.day);

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
    final colorScheme = theme.colorScheme;
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
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor),
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
            Icon(Icons.filter_alt_rounded, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 22,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    if (classes.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                    Icon(
                      Icons.filter_alt_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
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
                      selected == null
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                  onTap: () {
                    onSelect(null);
                    Navigator.pop(context);
                  },
                ),
                ...classes.map(
                  (c) => ListTile(
                    title: Text(c.name),
                    trailing: selected == c.id
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.primary,
                          )
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
