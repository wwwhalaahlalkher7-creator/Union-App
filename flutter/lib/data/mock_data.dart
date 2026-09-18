import 'package:flutter/material.dart';

/// Temporary local data used while the TRINEX UI is validated.
/// Switch [enabled] to false when the real backend integration is ready.
class MockData {
  MockData._();

  static const bool enabled = true;

  static const student = MockStudent(
    name: 'عمر خالد الصادق',
    number: '22-44005566',
    major: 'هندسة الحاسوب والبرمجيات',
    department: 'الهندسة المدنية',
    supervisor: 'د. ليلى الشريف',
    email: 'omar.comp@univ.edu',
    gpa: 3.92,
    maxGpa: 4.0,
    semester: 8,
    totalSemesters: 10,
    levelName: 'مهندس واعد',
    level: 7,
    xp: 1450,
    xpToNext: 150,
    earnedHours: 132,
    requiredHours: 150,
  );

  static const news = <MockNewsItem>[
    MockNewsItem(
      title: 'معرض مشاريع التخرج والعمارة السنوي (TRINEX 2026 Expo)',
      summary: 'انطلاق التحضيرات لمعرض التخرج بمشاركة شركات المقاولات والاستشارات الهندسية الرائدة لعرض الفرص الوظيفية والتدريبية.',
      date: '2026-09-10',
      category: 'event',
      comments: 4,
      likes: 267,
    ),
    MockNewsItem(
      title: 'إعلان رسمي: موعد تسليم الشيتات النصفية لجميع أقسام الكلية',
      summary: 'تهيب رابطة كلية الهندسة والعمارة بكافة الزملاء الالتزام بالمواعيد النهائية المعتمدة من المجالس الأكاديمية للأقسام.',
      date: '2026-09-15',
      category: 'official',
      comments: 3,
      likes: 118,
      pinned: true,
    ),
    MockNewsItem(
      title: 'فتح التسجيل في ورشة التصميم الرقمي للطلاب',
      summary: 'ورشة تطبيقية قصيرة حول أدوات التصميم الحديثة، مع شهادات حضور للمشاركين.',
      date: '2026-09-17',
      category: 'activity',
      comments: 8,
      likes: 94,
    ),
  ];

  static const materials = <MockMaterial>[
    MockMaterial('هندسة البرمجيات', 'SWE-401', 'محاضرة 01 — مقدمة في هندسة البرمجيات', Icons.menu_book_rounded, 18),
    MockMaterial('هندسة البرمجيات', 'SWE-401', 'محاضرة 02 — المتطلبات والتحليل', Icons.picture_as_pdf_rounded, 24),
    MockMaterial('قواعد البيانات', 'DB-402', 'SQL — الاستعلامات المتقدمة', Icons.storage_rounded, 12),
    MockMaterial('الشبكات', 'NET-403', 'Routing & Switching — Sheet 03', Icons.hub_rounded, 9),
    MockMaterial('هندسة مدنية', 'CE-405', 'Structural Analysis — Sheet 04', Icons.architecture_rounded, 15),
  ];

  static const schedule = <MockLecture>[
    MockLecture('الأحد', '09:00', 'هندسة البرمجيات', 'قاعة 204', Icons.code_rounded),
    MockLecture('الأحد', '12:00', 'قواعد البيانات', 'معمل الحاسوب 2', Icons.storage_rounded),
    MockLecture('الإثنين', '10:00', 'هندسة مدنية', 'قاعة 108', Icons.architecture_rounded),
    MockLecture('الثلاثاء', '11:00', 'الشبكات', 'معمل الشبكات', Icons.hub_rounded),
    MockLecture('الخميس', '09:30', 'مشروع التخرج', 'استديو المشاريع', Icons.auto_awesome_rounded),
  ];

  static const badges = <MockBadge>[
    MockBadge('رائد المنصة', 'التسجيل في منصة TRINEX في الإصدار 1.0.0 المعتمد', Icons.explore_rounded),
    MockBadge('مستكشف الشيتات', 'قراءة وإتمام أول شيت تمارين في المقررات الهندسية', Icons.menu_book_rounded),
    MockBadge('ملتزم', 'فتح المواد الدراسية لخمسة أيام متتالية', Icons.local_fire_department_rounded),
  ];
}

class MockStudent {
  const MockStudent({required this.name, required this.number, required this.major, required this.department, required this.supervisor, required this.email, required this.gpa, required this.maxGpa, required this.semester, required this.totalSemesters, required this.levelName, required this.level, required this.xp, required this.xpToNext, required this.earnedHours, required this.requiredHours});
  final String name, number, major, department, supervisor, email, levelName;
  final double gpa, maxGpa;
  final int semester, totalSemesters, level, xp, xpToNext, earnedHours, requiredHours;
}

class MockNewsItem {
  const MockNewsItem({required this.title, required this.summary, required this.date, required this.category, required this.comments, required this.likes, this.pinned = false});
  final String title, summary, date, category;
  final int comments, likes;
  final bool pinned;
}

class MockMaterial {
  const MockMaterial(this.subject, this.code, this.title, this.icon, this.pages);
  final String subject, code, title;
  final IconData icon;
  final int pages;
}

class MockLecture {
  const MockLecture(this.day, this.time, this.subject, this.room, this.icon);
  final String day, time, subject, room;
  final IconData icon;
}

class MockBadge {
  const MockBadge(this.title, this.description, this.icon);
  final String title, description;
  final IconData icon;
}
