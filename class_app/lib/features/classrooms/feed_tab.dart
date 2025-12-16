import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../data/models/classroom_detail_model.dart';
import '../announcements/announcements_controller.dart';
import '../announcements/announcements_page.dart';
import '../profile/profile_controller.dart';

class FeedTab extends ConsumerStatefulWidget {
  const FeedTab({super.key, required this.detail, required this.classroomId});

  final ClassroomDetailModel detail;
  final String classroomId;

  @override
  ConsumerState<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends ConsumerState<FeedTab> {
  late final TextEditingController _composerController;
  List<PlatformFile> _attachments = const [];

  @override
  void initState() {
    super.initState();
    _composerController = TextEditingController();
  }

  @override
  void dispose() {
    _composerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final annState =
        ref.watch(announcementsControllerProvider(widget.classroomId));
    final annNotifier =
        ref.read(announcementsControllerProvider(widget.classroomId).notifier);
    final profile = ref.watch(profileControllerProvider);
    final isTeacher = profile.user != null &&
        widget.detail.members.any(
          (m) =>
              m.userId == profile.user!.id &&
              (m.role ?? '').toLowerCase().contains('teacher'),
        );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isTeacher) ...[
            _Composer(
              controller: _composerController,
              attachments: _attachments,
              onAttach: () async {
                final result = await FilePicker.platform.pickFiles(
                  allowMultiple: true,
                );
                if (result != null && result.files.isNotEmpty) {
                  setState(() => _attachments = result.files);
                }
              },
              onRemoveAttachment: (file) {
                setState(
                  () => _attachments =
                      _attachments.where((f) => f != file).toList(),
                );
              },
              onSend: (text) async {
                if (text.trim().isEmpty) return;
                await annNotifier.create(
                  classroomId: widget.classroomId,
                  content: text.trim(),
                  attachments: _attachments,
                );
                _composerController.clear();
                setState(() => _attachments = const []);
              },
            ),
            const SizedBox(height: 20),
          ],
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Bảng tin',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          if (annState.isLoading && annState.items.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (annState.errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                annState.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          else if (annState.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Chưa có thông báo nào'),
            )
          else
            ...annState.items.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AnnouncementCard(
                  item: a,
                  classroomId: widget.classroomId,
                  showPreview: true,
                  isTeacher: isTeacher,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.onRemoveAttachment,
    required this.attachments,
  });

  final TextEditingController controller;
  final List<PlatformFile> attachments;
  final Future<void> Function(String text) onSend;
  final VoidCallback onAttach;
  final void Function(PlatformFile file) onRemoveAttachment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFE0ECFF),
                child: Icon(Icons.edit, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'Chia sẻ với lớp học...',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  minLines: 1,
                  maxLines: 3,
                ),
              ),
              IconButton(
                onPressed: onAttach,
                icon: const Icon(Icons.attach_file, color: Color(0xFF2563EB)),
              ),
              IconButton(
                onPressed: () => onSend(controller.text),
                icon: const Icon(Icons.send, color: Color(0xFF2563EB)),
              ),
            ],
          ),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: attachments
                    .map(
                      (f) => Chip(
                        label: Text(
                          f.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () => onRemoveAttachment(f),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}