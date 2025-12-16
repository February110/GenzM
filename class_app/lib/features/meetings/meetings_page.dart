import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/primary_button.dart';
import '../../data/models/meeting_model.dart';
import '../../data/repositories/meeting_repository_impl.dart';
import 'meeting_room_page.dart';

class MeetingsPage extends ConsumerWidget {
  const MeetingsPage({super.key, required this.classroomId});

  final String classroomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<MeetingData>(
      future: _load(ref),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: Text('Không có dữ liệu cuộc họp.'));
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cuộc họp',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () =>
                        ref.invalidate(_meetingsLoaderProvider(classroomId)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (data.active != null)
                _MeetingCard(
                  title: 'Đang hoạt động',
                  meeting: data.active!,
                  onJoin: () =>
                      _joinWithCode(context, ref, data.active!.roomCode),
                  onCopy: () => _copyCode(context, data.active!.roomCode),
                )
              else
                const Text('Không có cuộc họp đang hoạt động.'),
              const SizedBox(height: 16),
              Text('Lịch sử', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Expanded(
                child: data.history.isEmpty
                    ? const Center(child: Text('Chưa có lịch sử cuộc họp.'))
                    : ListView.separated(
                        itemCount: data.history.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final m = data.history[index];
                          return _MeetingCard(
                            title: null,
                            meeting: m,
                            onCopy: () => _copyCode(context, m.roomCode),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: 'Tạo (GV)',
                      onPressed: () => _createMeeting(context, ref),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _joinMeeting(context, ref),
                      child: const Text('Tham gia bằng mã'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<MeetingData> _load(WidgetRef ref) {
    return ref.read(_meetingsLoaderProvider(classroomId).future);
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

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({
    this.title,
    required this.meeting,
    this.onJoin,
    this.onCopy,
  });

  final String? title;
  final MeetingModel meeting;
  final VoidCallback? onJoin;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
            ],
            Text(meeting.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Mã: ${meeting.roomCode}'),
            const SizedBox(height: 4),
            Text('Trạng thái: ${meeting.status}'),
            if (meeting.startedAt != null)
              Text('Bắt đầu: ${meeting.startedAt}'),
            if (meeting.endedAt != null) Text('Kết thúc: ${meeting.endedAt}'),
            const SizedBox(height: 8),
            Row(
              children: [
                if (onJoin != null)
                  ElevatedButton.icon(
                    onPressed: onJoin,
                    icon: const Icon(Icons.meeting_room_outlined),
                    label: const Text('Vào phòng'),
                  ),
                const SizedBox(width: 8),
                if (onCopy != null)
                  OutlinedButton.icon(
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy),
                    label: const Text('Sao chép mã'),
                  ),
              ],
            ),
          ],
        ),
      ),
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
