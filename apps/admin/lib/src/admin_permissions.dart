import 'admin_section.dart';

/// UI-level navigation visibility matching backend role IDs.
/// This is only a usability layer; backend authorization remains authoritative.
abstract final class AdminPermissions {
  static const superAdmin = 'super_admin';
  static const contentManager = 'content_manager';
  static const academicManager = 'academic_manager';

  static bool canSee(String role, AdminSection section) {
    switch (role) {
      case superAdmin:
        return true;
      case contentManager:
        return const {AdminSection.overview, AdminSection.content, AdminSection.account}
            .contains(section);
      case academicManager:
        return const {
          AdminSection.overview,
          AdminSection.students,
          AdminSection.materials,
          AdminSection.schedule,
          AdminSection.account,
        }.contains(section);
      default:
        // Unknown or future roles receive the least-privilege navigation.
        return const {AdminSection.overview, AdminSection.account}.contains(section);
    }
  }

  static String roleLabel(String role) {
    switch (role) {
      case superAdmin:
        return 'مدير النظام';
      case contentManager:
        return 'مدير المحتوى';
      case academicManager:
        return 'مدير الشؤون الأكاديمية';
      default:
        return role.isEmpty ? 'دور غير محدد' : role;
    }
  }
}
