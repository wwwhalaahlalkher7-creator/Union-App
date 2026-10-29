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

    test('content manager sees content, marketplace, and dashboard tools', () {
      expect(AdminPermissions.canSee('content_manager', AdminSection.content), isTrue);
      expect(AdminPermissions.canSee('content_manager', AdminSection.market), isTrue);
      expect(AdminPermissions.canSee('content_manager', AdminSection.exams), isFalse);
      expect(AdminPermissions.canSee('content_manager', AdminSection.notifications), isFalse);
      expect(AdminPermissions.canSee('content_manager', AdminSection.overview), isTrue);
      expect(AdminPermissions.canSee('content_manager', AdminSection.analytics), isTrue);
      expect(AdminPermissions.canSee('content_manager', AdminSection.eino), isTrue);
      expect(AdminPermissions.canSee('content_manager', AdminSection.account), isTrue);
      expect(AdminPermissions.canSee('content_manager', AdminSection.staff), isFalse);
      expect(AdminPermissions.canSee('content_manager', AdminSection.security), isFalse);
      expect(AdminPermissions.canSee('content_manager', AdminSection.materials), isFalse);
    });

    test('academic manager sees academic and dashboard tools', () {
      expect(AdminPermissions.canSee('academic_manager', AdminSection.materials), isTrue);
      expect(AdminPermissions.canSee('academic_manager', AdminSection.schedule), isTrue);
      expect(AdminPermissions.canSee('academic_manager', AdminSection.exams), isTrue);
      expect(AdminPermissions.canSee('academic_manager', AdminSection.market), isFalse);
      expect(AdminPermissions.canSee('academic_manager', AdminSection.analytics), isTrue);
      expect(AdminPermissions.canSee('academic_manager', AdminSection.eino), isTrue);
      expect(AdminPermissions.canSee('academic_manager', AdminSection.content), isFalse);
      expect(AdminPermissions.canSee('academic_manager', AdminSection.staff), isFalse);
    });

    test('moderator sees the moderation, notifications, and dashboard APIs it is authorized to use', () {
      expect(AdminPermissions.canSee('moderator', AdminSection.overview), isTrue);
      expect(AdminPermissions.canSee('moderator', AdminSection.analytics), isTrue);
      expect(AdminPermissions.canSee('moderator', AdminSection.eino), isTrue);
      expect(AdminPermissions.canSee('moderator', AdminSection.feedbackInbox), isTrue);
      expect(AdminPermissions.canSee('moderator', AdminSection.notifications), isTrue);
      expect(AdminPermissions.canSee('moderator', AdminSection.account), isTrue);
      expect(AdminPermissions.canSee('moderator', AdminSection.students), isFalse);
      expect(AdminPermissions.canSee('moderator', AdminSection.staff), isFalse);
      expect(AdminPermissions.canSee('moderator', AdminSection.security), isFalse);
      expect(AdminPermissions.canSee('moderator', AdminSection.market), isFalse);
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
      expect(AdminPermissions.roleLabel('moderator'), 'مشرف البلاغات والإشعارات');
    });
  });
}
