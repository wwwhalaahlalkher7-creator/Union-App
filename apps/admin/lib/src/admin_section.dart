import 'package:flutter/material.dart';

enum AdminSection {
  overview('نظرة عامة', Icons.space_dashboard_outlined),
  analytics('التحليلات والاستخدام', Icons.query_stats_outlined),
  students('الطلاب', Icons.school_outlined),
  staff('الموظفون والصلاحيات', Icons.manage_accounts_outlined),
  content('المحتوى', Icons.article_outlined),
  materials('المواد الدراسية', Icons.menu_book_outlined),
  schedule('الجداول', Icons.calendar_month_outlined),
  feedbackReports('المقترحات والبلاغات', Icons.feedback_outlined),
  notifications('الإشعارات', Icons.notifications_active_outlined),
  security('الأمان وسجل التدقيق', Icons.shield_outlined),
  eino('مراقبة إينو', Icons.monitor_heart_outlined),
  settings('الإعدادات', Icons.settings_outlined),
  account('حسابي', Icons.person_outline);

  const AdminSection(this.title, this.icon);
  final String title;
  final IconData icon;
}
