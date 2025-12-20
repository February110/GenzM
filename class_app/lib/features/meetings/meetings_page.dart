import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/primary_button.dart';
import '../../data/models/meeting_model.dart';
import '../../data/repositories/meeting_repository_impl.dart';
import 'meeting_room_page.dart';

class MeetingsPage extends ConsumerWidget {
  const MeetingsPage({
    super.key,
    required this.classroomId,
    required this.isTeacher,
  });

  final String classroomId;
  final bool isTeacher;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dataAsync = ref.watch(_meetingsLoaderProvider(classroomId));

    return dataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (data) {
        final history = data.history;
        return Stack(
          children: [
            RefreshIndicator(
              color: colorScheme.primary,
              onRefresh: () async {
                ref.invalidate(_meetingsLoaderProvider(classroomId));
                await ref.read(_meetingsLoaderProvider(classroomId).future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Cuộc họp',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () =>
                            ref.invalidate(_meetingsLoaderProvider(classroomId)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _ActiveMeetingCard(
                    meeting: data.active,
                    onJoin: data.active == null
                        ? null
                        : () => _joinWithCode(context, ref, data.active!.roomCode),
                    onCopy: data.active == null
                        ? null
                        : () => _copyCode(context, data.active!.roomCode),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Lịch sử',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  if (history.isEmpty)
                    _EmptyCard(
                      icon: Icons.history_toggle_off,
                      message: 'Chưa có lịch sử cuộc họp.',
                    )
                  else
                    ...history.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MeetingCard(
                          meeting: m,
                          onCopy: () => _copyCode(context, m.roomCode),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (isTeacher)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _createMeeting(context, ref),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const StadiumBorder(),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Tạo cuộc họp',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    if (isTeacher) const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _joinMeeting(context, ref),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const StadiumBorder(),
                          side: BorderSide(color: colorScheme.primary),
                        ),
                        child: Text(
                          'Tham gia bằng mã',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createMeeting(BuildContext context, WidgetRef ref) async {
    final titleController = TextEditingController();
    final repo = ref.read(meetingRepositoryProvider);
    final result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Tạo cuộc họp (giáo viên)'),
          content: TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Tiêu đề (tuỳ chọn)'),
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
    if (result != true) return;
    try {
      final meeting = await repo.create(
        classroomId,
        title: titleController.text.trim().isEmpty
            ? null
            : titleController.text.trim(),
      );
      ref.invalidate(_meetingsLoaderProvider(classroomId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tạo cuộc họp: ${meeting.roomCode}')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _joinMeeting(BuildContext context, WidgetRef ref) async {
    final codeController = TextEditingController();
    final repo = ref.read(meetingRepositoryProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Tham gia bằng mã phòng'),
          content: TextField(
            controller: codeController,
            decoration: const InputDecoration(labelText: 'Room code'),
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
    if (ok != true) return;
    try {
      final result = await repo.join(codeController.text.trim());
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MeetingRoomPage(result: result)),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _joinWithCode(
    BuildContext context,
    WidgetRef ref,
    String code,
  ) async {
    try {
      final result = await ref.read(meetingRepositoryProvider).join(code);
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MeetingRoomPage(result: result)),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _copyCode(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã sao chép mã: $code')));
    }
  }
}

class _ActiveMeetingCard extends StatelessWidget {
  const _ActiveMeetingCard({
    required this.meeting,
    this.onJoin,
    this.onCopy,
  });

  final MeetingModel? meeting;
  final VoidCallback? onJoin;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (meeting == null) {
      return _EmptyCard(
        icon: Icons.videocam_off_outlined,
        message: 'Chưa có cuộc họp đang hoạt động.',
      );
    }

    final m = meeting!;
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusChip(text: 'Đang hoạt động', color: const Color(0xFF10B981)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy_outlined, size: 20),
                tooltip: 'Sao chép mã',
                onPressed: onCopy,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            m.title.isNotEmpty ? m.title : 'Phòng trực tuyến',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          _InfoRow(
            icon: Icons.confirmation_number_outlined,
            label: 'Mã phòng',
            value: m.roomCode,
          ),
          const SizedBox(height: 4),
          _InfoRow(
            icon: Icons.schedule_outlined,
            label: 'Bắt đầu',
            value: _formatDate(m.startedAt),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onJoin,
                  icon: const Icon(Icons.meeting_room_outlined),
                  label: const Text('Vào phòng'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: onCopy,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Sao chép mã'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({
    required this.meeting,
    this.onCopy,
  });

  final MeetingModel meeting;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final status = meeting.status.toLowerCase();
    final isEnded = status.contains('end');
    final chipColor = isEnded ? const Color(0xFFF97316) : const Color(0xFF0EA5E9);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  meeting.title.isNotEmpty ? meeting.title : 'Không tên',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              _StatusChip(
                text: isEnded ? 'Đã kết thúc' : meeting.status,
                color: chipColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.confirmation_number_outlined,
            label: 'Mã phòng',
            value: meeting.roomCode,
            trailing: IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: onCopy,
              tooltip: 'Sao chép mã',
            ),
          ),
          const SizedBox(height: 4),
          _InfoRow(
            icon: Icons.schedule_outlined,
            label: 'Bắt đầu',
            value: _formatDate(meeting.startedAt),
          ),
          if (meeting.endedAt != null) ...[
            const SizedBox(height: 4),
            _InfoRow(
              icon: Icons.timer_off_outlined,
              label: 'Kết thúc',
              value: _formatDate(meeting.endedAt),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.isEmpty ? '—' : value,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class MeetingData {
  MeetingData({this.active, required this.history});

  final MeetingModel? active;
  final List<MeetingModel> history;
}

final _meetingsLoaderProvider = FutureProvider.family<MeetingData, String>((
  ref,
  classroomId,
) async {
  final repo = ref.read(meetingRepositoryProvider);
  final active = await repo.getActive(classroomId);
  final history = await repo.getHistory(classroomId);
  return MeetingData(active: active, history: history);
});

String _formatDate(DateTime? time) {
  if (time == null) return '';
  final local = time.toLocal();
  return DateFormat('HH:mm dd/MM/yyyy').format(local);
}
