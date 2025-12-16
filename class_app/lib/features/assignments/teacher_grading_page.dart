import 'package:flutter/material.dart';

import '../../data/models/assignment_model.dart';
import '../../data/models/submission_model.dart';
import '../../data/models/classroom_detail_model.dart';
import 'package:intl/intl.dart';

class TeacherGradingPage extends StatelessWidget {
  const TeacherGradingPage({
    super.key,
    required this.assignment,
    required this.submissions,
    this.classroomName,
    this.members = const [],
  });

  final AssignmentModel assignment;
  final List<SubmissionModel> submissions;
  final String? classroomName;
  final List<ClassroomMember> members;

  @override
  Widget build(BuildContext context) {
    final submitted = submissions;
    final pendingCount =
        (members.isNotEmpty ? members.length - submissions.length : 0)
            .clamp(0, 999);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
          assignment.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headerCard(),
          const SizedBox(height: 12),
          _sectionTitle('Danh sách lớp', trailing: classroomName),
          const SizedBox(height: 8),
          _chips(submittedCount: submitted.length, pendingCount: pendingCount),
          const SizedBox(height: 12),
          if (submitted.isEmpty && pendingCount == 0)
            const Center(
              child: Text(
                'Chưa có học viên trong lớp.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          else ...[
            _studentsScroller(),
            const SizedBox(height: 12),
            ...submitted.map((s) => _submissionTile(context, s, true)),
          ],
          const SizedBox(height: 24),
          _sectionTitle('Đánh giá & Phản hồi'),
          const SizedBox(height: 8),
          _gradingBox(),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: _actionsBar(),
    );
  }

  Widget _headerCard() {
    final due = assignment.dueAt != null
        ? 'Hạn: ${assignment.dueAt!.toLocal().toString().substring(0, 16)}'
        : 'Không hạn';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            assignment.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          if (assignment.maxPoints != null)
            Text(
              'Tối đa: ${assignment.maxPoints} điểm',
              style: const TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            due,
            style: const TextStyle(
              color: Color(0xFFDC2626),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, {String? trailing}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _chips({required int submittedCount, required int pendingCount}) {
    return Row(
      children: [
        _chip('Đã nộp', submittedCount.toString(), highlighted: true),
        const SizedBox(width: 8),
        _chip('Chưa nộp', pendingCount.toString(), highlighted: false),
      ],
    );
  }

  Widget _chip(String label, String count, {required bool highlighted}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? const Color(0xFF2563EB).withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: highlighted ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: highlighted
                  ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count,
              style: TextStyle(
                color: highlighted ? const Color(0xFF2563EB) : const Color(0xFF475569),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _submissionTile(BuildContext context, SubmissionModel sub, bool submitted) {
    const name = 'Học viên';
    final at = DateFormat('HH:mm dd/MM').format(sub.submittedAt.toLocal());
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: submitted
                      ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  submitted ? 'Đã nộp' : 'Chưa nộp',
                  style: TextStyle(
                    color: submitted ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            submitted ? 'Nộp lúc $at' : 'Chưa nộp',
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF6B7280),
            ),
          ),
          if (submitted && sub.fileKey.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                color: const Color(0xFFF8FAFC),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sub.fileKey.split('/').last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.visibility),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gradingBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Điểm số',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Điểm',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                assignment.maxPoints != null ? '/${assignment.maxPoints}' : '/100',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Nhận xét',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Nhập nhận xét cho học viên...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionsBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              child: const Text(
                'Lưu nháp',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.send),
              label: const Text(
                'Trả bài',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studentsScroller() {
    if (members.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: List.generate(members.length, (i) {
          final m = members[i];
          final submitted = i < submissions.length;
          final name = m.fullName ?? 'HV ${i + 1}';
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor:
                          submitted ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                      child: CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.white,
                        child: m.avatar != null
                            ? ClipOval(
                                child: Image.network(
                                  m.avatar!,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Text(
                                _initials(name),
                                style: TextStyle(
                                  color:
                                      submitted ? const Color(0xFF2563EB) : const Color(0xFF475569),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                    if (submitted)
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.check, size: 12, color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 70,
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'HV';
    if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
    final first = parts.first.characters.take(1).toString();
    final last = parts.last.characters.take(1).toString();
    return (first + last).toUpperCase();
  }
}
