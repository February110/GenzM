import '../../data/models/classroom_model.dart';
import '../../data/models/classroom_detail_model.dart';

abstract class ClassroomRepository {
  Future<List<ClassroomModel>> getClassrooms();
  Future<void> joinClassroom(String inviteCode);
  Future<ClassroomModel> createClassroom({
    required String name,
    String? description,
    String? section,
    String? room,
    String? schedule,
  });
  Future<ClassroomDetailModel> getClassroomDetail(String classroomId);
  Future<String> changeBanner(String classroomId);
  Future<bool> setInviteCodeVisibility(String classroomId, bool visible);
}
