import 'package:flutter_test/flutter_test.dart';
import 'package:trinex_admin/src/admin_permissions.dart';
import 'package:trinex_admin/src/admin_section.dart';

void main() {
  group('AdminPermissions', () {
    test('super admin can see every section', () {
      for (final section in AdminSection.values) {
        expect(AdminPermissions.canSee('super_admin', section), isTrue);
      }
    });

    test('content manager only sees content-related navigation', () {
      expect(AdminPermissions.canSee('content_manager', AdminSection.content), isTrue);
      expect(AdminPermissions.canSee('content_manager', AdminSection.notifications), isFalse);
      expect(AdminPermissions.canSee('content_manager', AdminSection.overview), isTrue);
      expect(AdminPermissions.canSee('content_manager', AdminSection.account), isTrue);
      expect(AdminPermissions.canSee('content_manager', AdminSection.staff), isFalse);
      expect(AdminPermissions.canSee('content_manager', AdminSection.security), isFalse);
      expect(AdminPermissions.canSee('content_manager', AdminSection.materials), isFalse);
    });

    test('academic manager sees academic sections only', () {
      expect(AdminPermissions.canSee('academic_manager', AdminSection.materials), isTrue);
      expect(AdminPermissions.canSee('academic_manager', AdminSection.schedule), isTrue);
      expect(AdminPermissions.canSee('academic_manager', AdminSection.content), isFalse);
      expect(AdminPermissions.canSee('academic_manager', AdminSection.staff), isFalse);
    });

    test('legacy staff moderator role is no longer granted dashboard navigation', () {
      expect(AdminPermissions.canSee('moderator', AdminSection.overview), isTrue);
      expect(AdminPermissions.canSee('moderator', AdminSection.account), isTrue);
      expect(AdminPermissions.canSee('moderator', AdminSection.feedbackReports), isFalse);
      expect(AdminPermissions.canSee('moderator', AdminSection.students), isFalse);
      expect(AdminPermissions.canSee('moderator', AdminSection.staff), isFalse);
    });

    test('unknown roles receive least-privilege navigation', () {
      expect(AdminPermissions.canSee('new_role', AdminSection.overview), isTrue);
      expect(AdminPermissions.canSee('new_role', AdminSection.account), isTrue);
      expect(AdminPermissions.canSee('new_role', AdminSection.students), isFalse);
      expect(AdminPermissions.canSee('', AdminSection.settings), isFalse);
    });

    test('role IDs map to Arabic labels', () {
      expect(AdminPermissions.roleLabel('super_admin'), 'مدير النظام');
      expect(AdminPermissions.roleLabel('academic_manager'), 'مدير الشؤون الأكاديمية');
    });
  });
}
