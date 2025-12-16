import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/meeting_join_result.dart';

class MeetingRoomPage extends StatelessWidget {
  const MeetingRoomPage({super.key, required this.result});

  final MeetingJoinResult result;

  @override
  Widget build(BuildContext context) {
    final meeting = result.meeting;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phòng học trực tuyến'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Sao chép mã',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: meeting.roomCode));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã sao chép mã: ${meeting.roomCode}')),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.meeting_room_outlined),
                title: Text(meeting.title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mã: ${meeting.roomCode}'),
                    Text('Trạng thái: ${meeting.status}'),
                    if (meeting.startedAt != null)
                      Text('Bắt đầu: ${meeting.startedAt}'),
                    if (meeting.endedAt != null) Text('Kết thúc: ${meeting.endedAt}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('Lớp: ${result.classroom.name}'),
            const SizedBox(height: 6),
            Text('Vai trò của bạn: ${result.role.isEmpty ? 'Thành viên' : result.role}'),
            const SizedBox(height: 12),
            Text('Thành viên tham gia', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: result.classroom.members.isEmpty
                  ? const Center(child: Text('Chưa có danh sách thành viên.'))
                  : ListView.builder(
                      itemCount: result.classroom.members.length,
                      itemBuilder: (_, index) {
                        final m = result.classroom.members[index];
                        return ListTile(
                          leading: CircleAvatar(child: Text(m.fullName.isNotEmpty ? m.fullName[0] : '?')),
                          title: Text(m.fullName),
                          subtitle: Text(m.userId),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ghi chú: Đây là màn thông tin phòng. Nếu cần tích hợp phòng họp thực (WebRTC/SignalR), sẽ nối thêm client.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}
