import 'package:flutter/material.dart';

enum AdminSection {
  overview('نظرة عامة', Icons.space_dashboard_outlined),
  analytics('إحصاءات النظام', Icons.query_stats_outlined),
  students('الطلاب', Icons.school_outlined),
  staff('الموظفون والصلاحيات', Icons.manage_accounts_outlined),
  content('المحتوى', Icons.article_outlined),
  materials('المواد الدراسية', Icons.menu_book_outlined),
  schedule('الجداول', Icons.calendar_month_outlined),
  market('السوق', Icons.storefront_outlined),
  exams('إدارة الامتحانات', Icons.picture_as_pdf_outlined),
  feedbackInbox('البلاغات والمقترحات', Icons.report_gmailerrorred_outlined),
  notifications('الإشعارات', Icons.notifications_active_outlined),
  security('الأمان وسجل التدقيق', Icons.shield_outlined),
  eino('مراقبة إينو', Icons.monitor_heart_outlined),
  settings('الإعدادات', Icons.settings_outlined),
  account('حسابي', Icons.person_outline);

  const AdminSection(this.title, this.icon);
  final String title;
  final IconData icon;
}
