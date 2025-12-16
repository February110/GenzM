import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_config.dart';
import '../../core/widgets/primary_button.dart';
import '../../data/models/announcement_attachment_model.dart';
import '../../data/models/announcement_comment_model.dart';
import '../../data/models/announcement_model.dart';
import '../../data/repositories/announcement_repository_impl.dart';
import '../classrooms/classroom_detail_provider.dart';
import '../profile/profile_controller.dart';
import 'announcements_controller.dart';
import 'comments_provider.dart';

class AnnouncementsPage extends ConsumerWidget {
  const AnnouncementsPage({
    super.key,
    required this.classroomId,
    this.className,
  });

  final String classroomId;
  final String? className;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider);
    final detailAsync = ref.watch(classroomDetailProvider(classroomId));
    final state = ref.watch(announcementsControllerProvider(classroomId));
    final notifier = ref.read(
      announcementsControllerProvider(classroomId).notifier,
    );
    final detail = detailAsync.valueOrNull;
    final isTeacher = profile.user != null &&
        detail?.members.any(
              (m) =>
                  m.userId == profile.user!.id &&
                  (m.role ?? '').toLowerCase().contains('teacher'),
            ) ==
            true;

    // ====== UI States (đặt ngoài list cho gọn + đúng) ======
    Widget sliverBody() {
      if (state.isLoading && state.items.isEmpty) {
        return const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        );
      }

      if (state.errorMessage != null) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  state.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Thử lại',
                  onPressed: () => notifier.load(classroomId),
                ),
              ],
            ),
          ),
        );
      }

      if (state.items.isEmpty) {
        return const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text('Chưa có thông báo.')),
        );
      }

      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final item = state.items[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AnnouncementCard(
                item: item,
                classroomId: classroomId,
                showPreview: true,
                isTeacher: isTeacher,
              ),
            );
          }, childCount: state.items.length),
        ),
      );
    }

    return Container(
      color: const Color(0xFFF5F7FB),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _Header(
                title: className ?? 'Thông báo',
                onProfile: () {},
                onRefresh: () => notifier.load(classroomId),
              ),
            ),
            const SizedBox(height: 10),

            // Share box
            if (isTeacher) ...[
            if (isTeacher) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ShareBox(
                  onTap: () => _showCreateDialog(context, notifier),
                ),
              ),
              const SizedBox(height: 10),
            ],
            ],

            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF2563EB),
                onRefresh: () => notifier.load(classroomId),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    sliverBody(),
                    const SliverToBoxAdapter(child: SizedBox(height: 90)),
                  ],
                ),
              ),
            ),

            if (isTeacher)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: PrimaryButton(
                  label: 'Tạo thông báo',
                  isLoading: state.isLoading,
                  onPressed: () => _showCreateDialog(context, notifier),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(
    BuildContext context,
    AnnouncementsController notifier,
  ) {
    final contentController = TextEditingController();
    List<PlatformFile> attachments = const [];
    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            Future<void> pickFiles() async {
              final result = await FilePicker.platform.pickFiles(
                allowMultiple: true,
              );
              if (result != null && result.files.isNotEmpty) {
                setState(() => attachments = result.files);
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              title: const Text('Tạo thông báo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: contentController,
                      decoration: const InputDecoration(
                        labelText: 'Nội dung',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: pickFiles,
                          icon: const Icon(Icons.attach_file, size: 18),
                          label: const Text('Đính kèm tệp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (attachments.isNotEmpty)
                          Text(
                            '${attachments.length} tệp',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    if (attachments.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
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
                                onDeleted: () => setState(
                                  () => attachments =
                                      attachments.where((x) => x != f).toList(),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                TextButton(
                  onPressed: () async {
                    if (contentController.text.trim().isEmpty) return;
                    await notifier.create(
                      classroomId: classroomId,
                      content: contentController.text.trim(),
                      attachments: attachments,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Tạo'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class AnnouncementCard extends ConsumerStatefulWidget {
  const AnnouncementCard({
    super.key,
    required this.item,
    required this.classroomId,
    this.showPreview = false,
    this.isTeacher = false,
  });

  final AnnouncementModel item;
  final String classroomId;
  final bool showPreview;
  final bool isTeacher;

  @override
  ConsumerState<AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends ConsumerState<AnnouncementCard> {
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _commentController;
  bool _sendingComment = false;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
  }

  void _openEditDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.item.content);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Chỉnh sửa thông báo'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Nội dung',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              ref
                  .read(announcementsControllerProvider(widget.classroomId)
                      .notifier)
                  .update(widget.item.id, text)
                  .then((_) {
                if (context.mounted) Navigator.pop(context);
              });
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa thông báo?'),
        content: const Text('Bạn chắc chắn muốn xóa thông báo này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(announcementsControllerProvider(widget.classroomId)
                      .notifier)
                  .delete(widget.item.id)
                  .then((_) {
                if (context.mounted) Navigator.pop(context);
              });
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitInline() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sendingComment = true);
    final commentsProvider = announcementCommentsProvider(widget.item.id);
    try {
      await ref.read(announcementRepositoryProvider).addComment(
            announcementId: widget.item.id,
            content: text,
          );
      ref.invalidate(commentsProvider);
      final updated = await ref.refresh(commentsProvider.future);
      if (_scrollController.hasClients && updated.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 50));
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
      _commentController.clear();
    } finally {
      if (mounted) {
        setState(() => _sendingComment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = widget.showPreview
        ? ref.watch(announcementCommentsProvider(widget.item.id))
        : null;
    final creatorAvatar = AppConfig.resolveAssetUrl(widget.item.createdByAvatar);
    final attachments = widget.item.attachments;
    final profile = ref.watch(profileControllerProvider).user;
    final currentAvatar = AppConfig.resolveAssetUrl(profile?.avatar);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  _AvatarBubble(
                    name: widget.item.createdByName,
                    avatarUrl: creatorAvatar,
                    radius: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.createdByName ?? 'Giáo viên',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _timeAgo(widget.item.createdAt),
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (widget.isTeacher)
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_horiz,
                        color: Color(0xFF6B7280),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (v) {
                        if (v == 'edit') {
                          _openEditDialog(context);
                        } else if (v == 'delete') {
                          _confirmDelete(context);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Chỉnh sửa'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Xóa'),
                        ),
                      ],
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Content block (title + body)
              Text(
                widget.item.content.split('\n').first,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  height: 1.3,
                ),
              ),
              if (widget.item.content.contains('\n')) ...[
                const SizedBox(height: 6),
                Text(
                  widget.item.content.split('\n').skip(1).join('\n'),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF374151),
                  ),
                ),
              ],

              if (attachments.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...attachments.map(
                  (file) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AttachmentTile(file: file),
                  ),
                ),
              ],

              const SizedBox(height: 12),
              const Divider(color: Color(0xFFE5E7EB), height: 24),

              // Comments preview
              if (widget.showPreview && commentsAsync != null)
                commentsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                  error: (error, _) => Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      error.toString(),
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                  data: (comments) {
                    final preview = comments.take(2).toList();
                    final hasMore = comments.length > preview.length;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline,
                              size: 18,
                              color: Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Nhận xét (${comments.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (comments.isEmpty)
                          const Text(
                            'Chưa có bình luận.',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 12.5,
                            ),
                          )
                        else ...[
                          ...preview.map(
                            (c) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _InlineCommentTile(
                                comment: c,
                              ),
                            ),
                          ),
                          if (hasMore)
                            GestureDetector(
                              onTap: () {
                                showModalBottomSheet<void>(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.white,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                  ),
                                  builder: (_) {
                                    return DraggableScrollableSheet(
                                      initialChildSize: 0.7,
                                      minChildSize: 0.5,
                                      maxChildSize: 0.9,
                                      expand: false,
                                      builder: (_, scrollController) {
                                        return Padding(
                                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Center(
                                                child: Container(
                                                  width: 36,
                                                  height: 4,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade300,
                                                    borderRadius: BorderRadius.circular(999),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  const Icon(Icons.chat_bubble_outline,
                                                      size: 20, color: Color(0xFF2563EB)),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Tất cả bình luận (${comments.length})',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 16,
                                                      color: Color(0xFF111827),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Expanded(
                                                child: ListView.separated(
                                                  controller: scrollController,
                                                  itemBuilder: (_, idx) => _InlineCommentTile(
                                                    comment: comments[idx],
                                                  ),
                                                  separatorBuilder: (_, __) =>
                                                      const SizedBox(height: 12),
                                                  itemCount: comments.length,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                              child: Text(
                                'Xem thêm ${comments.length - preview.length} bình luận...',
                                style: const TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                            children: [
                            _AvatarBubble(
                              name: profile?.name,
                              avatarUrl: currentAvatar,
                              radius: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                decoration: InputDecoration(
                                  hintText: 'Thêm nhận xét trong lớp học...',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 13,
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF9FAFB),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF2563EB),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                minLines: 1,
                                maxLines: 3,
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 44,
                              width: 44,
                              child: ElevatedButton(
                                onPressed: _sendingComment ? null : _submitInline,
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: const CircleBorder(),
                                  backgroundColor: const Color(0xFF2563EB),
                                ),
                                child: _sendingComment
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Icon(Icons.send, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),

            ],
          ),
        ),
      ),
    );
  }


}

class _AvatarBubble extends StatelessWidget {
  const _AvatarBubble({
    required this.name,
    required this.avatarUrl,
    this.radius = 16,
  });

  final String? name;
  final String avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = (name != null && name!.isNotEmpty)
        ? name![0].toUpperCase()
        : 'N';
    final hasAvatar = avatarUrl.isNotEmpty;
    final isSvg = AppConfig.isSvgUrl(avatarUrl);

    if (hasAvatar && isSvg) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFE0ECFF),
        child: ClipOval(
          child: SvgPicture.network(
            avatarUrl,
            fit: BoxFit.cover,
            placeholderBuilder: (_) =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE0ECFF),
      backgroundImage: hasAvatar ? NetworkImage(avatarUrl) : null,
      child: hasAvatar
          ? null
          : Text(
              initial,
              style: const TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class _InlineCommentTile extends StatelessWidget {
  const _InlineCommentTile({required this.comment});

  final AnnouncementCommentModel comment;

  @override
  Widget build(BuildContext context) {
    final name = comment.userName ?? 'Người dùng';
    final avatarUrl = AppConfig.resolveAssetUrl(comment.userAvatar);
    final hasAvatar = avatarUrl.isNotEmpty;
    final isSvg = AppConfig.isSvgUrl(avatarUrl);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFE0ECFF),
          backgroundImage: hasAvatar && !isSvg ? NetworkImage(avatarUrl) : null,
          child: hasAvatar
              ? (isSvg
                  ? ClipOval(
                      child: SvgPicture.network(
                        avatarUrl,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        placeholderBuilder: (_) =>
                            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    )
                  : null)
              : Text(
                  name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Text(
                    _timeAgo(comment.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                comment.content,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF4B5563),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AttachmentTile extends StatefulWidget {
  const _AttachmentTile({required this.file});

  final AnnouncementAttachmentModel file;

  @override
  State<_AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends State<_AttachmentTile> {
  bool _downloading = false;
  double? _progress;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _syncLocalState();
  }

  String _formatSize(int? size) {
    if (size == null || size <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    double v = size.toDouble();
    int i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(v >= 10 ? 0 : 1)} ${units[i]}';
  }

  Future<String> _resolveSavePath() async {
    final directory = await getApplicationDocumentsDirectory();
    final rawUrl = AppConfig.resolveAssetUrl(widget.file.url ?? '');
    final url = Uri.tryParse(rawUrl);
    final fallbackName = url?.pathSegments.lastWhere(
          (s) => s.isNotEmpty,
          orElse: () => 'file',
        ) ??
        'file';
    final name =
        (widget.file.name.isNotEmpty ? widget.file.name : fallbackName)
            .replaceAll(RegExp(r'[\\\\/:*?\"<>|]'), '_');
    return '${directory.path}/$name';
  }

  Future<void> _syncLocalState() async {
    final savePath = await _resolveSavePath();
    if (await File(savePath).exists()) {
      if (mounted) {
        setState(() => _localPath = savePath);
      }
    }
  }

  Future<void> _download(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final rawUrl = AppConfig.resolveAssetUrl(widget.file.url ?? '');
    if (rawUrl.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Không tìm thấy link tải')),
      );
      return;
    }

    // Nếu là link ngoài (size = 0, key dạng link-), chỉ mở trực tiếp.
    if ((widget.file.size ?? 0) == 0 &&
        (widget.file.key?.startsWith('link-') ?? false)) {
      await OpenFilex.open(rawUrl);
      return;
    }

    setState(() {
      _downloading = true;
      _progress = 0;
    });

    try {
      final savePath = await _resolveSavePath();
      final name = savePath.split(Platform.pathSeparator).last;

      await Dio().download(
        rawUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            setState(() => _progress = received / total);
          }
        },
      );

      if (!mounted) return;
      setState(() => _localPath = savePath);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Đã tải xuống: $name'),
          action: SnackBarAction(
            label: 'Mở',
            onPressed: () => OpenFilex.open(savePath),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Tải xuống thất bại: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.file.name;
    final sizeText = _formatSize(widget.file.size);
    final url = AppConfig.resolveAssetUrl(widget.file.url ?? '');
    final ext = name.split('.').last.toUpperCase();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _downloading
            ? null
            : () {
                if (_localPath != null) {
                  OpenFilex.open(_localPath!);
                } else {
                  _download(context);
                }
              },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E7FF)),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5F5)),
                ),
                child: Center(
                  child: Text(
                    ext.length > 4 ? ext.substring(0, 4) : ext,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2563EB),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (sizeText.isNotEmpty)
                      Text(
                        sizeText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    if (_downloading)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _progress != null
                                  ? '${(_progress! * 100).toStringAsFixed(0)}%'
                                  : 'Đang tải...',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (url.isNotEmpty && !_downloading)
                IconButton(
                  icon: Icon(
                    _localPath != null
                        ? Icons.open_in_new_rounded
                        : Icons.download_rounded,
                    color: const Color(0xFF2563EB),
                  ),
                  tooltip: _localPath != null ? 'Mở tệp' : 'Tải xuống',
                  onPressed: () {
                    if (_localPath != null) {
                      OpenFilex.open(_localPath!);
                    } else {
                      _download(context);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onProfile,
    required this.onRefresh,
  });

  final String title;
  final VoidCallback onProfile;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF1F2937)),
              onPressed: onRefresh,
              tooltip: 'Làm mới',
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            GestureDetector(
              onTap: onProfile,
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFE0ECFF),
                child: Icon(Icons.person, color: Color(0xFF2563EB)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareBox extends StatelessWidget {
  const _ShareBox({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFE0ECFF),
                child: Icon(Icons.edit, color: Color(0xFF2563EB), size: 18),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Chia sẻ với lớp học của bạn...',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.image_outlined, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}

String _timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time.toLocal());
  if (diff.inMinutes < 1) return 'Vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  if (diff.inHours < 24) return '${diff.inHours} giờ trước';
  if (diff.inDays == 1) return 'Hôm qua';
  return DateFormat('HH:mm dd/MM/yyyy').format(time.toLocal());
}
