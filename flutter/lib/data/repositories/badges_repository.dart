import '../../core/network/api_client.dart';
import '../models/badge_item.dart';
import '../models/xp_snapshot.dart';
import 'repository_parser.dart';

class BadgesRepository {
  BadgesRepository(this._client);

  final ApiClient _client;


  /// Local safety-net used when the badges endpoint is unavailable. Badge
  /// definitions are application-owned, so the XP screen must never become
  /// unusable just because the optional badge metrics request failed.
  static BadgeSnapshot fallbackForXp(XpSnapshot xp) {
    const catalog = <List<dynamic>>[
      ['badge-first-step','البداية','ابدأ أول تقدم دراسي موثق.','progress_events',1],
      ['badge-five-progress','خطوة ثابتة','سجّل 5 عمليات تقدم دراسي.','progress_events',5],
      ['badge-ten-progress','مواظب','سجّل 10 عمليات تقدم دراسي.','progress_events',10],
      ['badge-twentyfive-progress','متابع قوي','سجّل 25 عملية تقدم دراسي.','progress_events',25],
      ['badge-fifty-progress','لا تتوقف','سجّل 50 عملية تقدم دراسي.','progress_events',50],
      ['badge-hundred-progress','مئة خطوة','سجّل 100 عملية تقدم دراسي.','progress_events',100],
      ['badge-quarter-thousand-progress','ربع ألف','سجّل 250 عملية تقدم دراسي.','progress_events',250],
      ['badge-first-complete','أول إنجاز','أكمل أول ملف دراسي.','completed_materials',1],
      ['badge-three-complete','ثلاثة ملفات','أكمل 3 ملفات دراسية.','completed_materials',3],
      ['badge-five-complete','خمسة ملفات','أكمل 5 ملفات دراسية.','completed_materials',5],
      ['badge-ten-complete','عشرة ملفات','أكمل 10 ملفات دراسية.','completed_materials',10],
      ['badge-twenty-complete','عشرون ملفًا','أكمل 20 ملفًا دراسيًا.','completed_materials',20],
      ['badge-thirty-complete','ثلاثون ملفًا','أكمل 30 ملفًا دراسيًا.','completed_materials',30],
      ['badge-fifty-complete','موسوعة','أكمل 50 ملفًا دراسيًا.','completed_materials',50],
      ['badge-first-subject','أول مادة','أكمل مادة دراسية واحدة.','completed_subjects',1],
      ['badge-three-subjects','متعدد المواد','أكمل مواد من 3 مقررات مختلفة.','completed_subjects',3],
      ['badge-five-subjects','واسع المعرفة','أكمل مواد من 5 مقررات مختلفة.','completed_subjects',5],
      ['badge-eight-subjects','جامع المقررات','أكمل مواد من 8 مقررات مختلفة.','completed_subjects',8],
      ['badge-xp-50','أول دفعة','اجمع 50 XP.','xp_total',50],
      ['badge-xp-100','مئة XP','اجمع 100 XP.','xp_total',100],
      ['badge-xp-250','ربع ألف XP','اجمع 250 XP.','xp_total',250],
      ['badge-xp-500','500 XP','اجمع 500 XP.','xp_total',500],
      ['badge-xp-1000','1000 XP','اجمع 1000 XP.','xp_total',1000],
      ['badge-xp-2000','2000 XP','اجمع 2000 XP.','xp_total',2000],
      ['badge-xp-5000','5000 XP','اجمع 5000 XP.','xp_total',5000],
      ['badge-level-2','المستوى 2','وصل إلى المستوى الثاني.','level',2],
      ['badge-level-3','المستوى 3','وصل إلى المستوى الثالث.','level',3],
      ['badge-level-5','المستوى 5','وصل إلى المستوى الخامس.','level',5],
      ['badge-level-10','المستوى 10','وصل إلى المستوى العاشر.','level',10],
      ['badge-level-15','المستوى 15','وصل إلى المستوى الخامس عشر.','level',15],
      ['badge-first-event','أول حدث','أكمل أول حدث تعليمي.','learning_events',1],
      ['badge-five-events','محب التعلم','أكمل 5 أحداث تعليمية.','learning_events',5],
      ['badge-ten-events','صانع العادة','أكمل 10 أحداث تعليمية.','learning_events',10],
      ['badge-first-comment','صوتك مهم','اكتب أول تعليق ظاهر.','comments',1],
      ['badge-five-comments','مشارك','اكتب 5 تعليقات ظاهرة.','comments',5],
      ['badge-ten-comments','حوار مستمر','اكتب 10 تعليقات ظاهرة.','comments',10],
      ['badge-first-reaction','تفاعل أول','أضف أول تفاعل.','reactions',1],
      ['badge-ten-reactions','متفاعل','أضف 10 تفاعلات.','reactions',10],
      ['badge-first-reply','مجيب','اكتب أول رد على تعليق.','replies',1],
      ['badge-five-replies','حوار بنّاء','اكتب 5 ردود على التعليقات.','replies',5],
    ];
    final badges = catalog.map((b) {
      final type = b[3] as String;
      final required = b[4] as int;
      final current = type == 'xp_total' ? xp.totalXp : type == 'level' ? xp.level : 0;
      final earned = (type == 'xp_total' || type == 'level') && current >= required;
      return BadgeItem(
        id: b[0] as String,
        name: b[1] as String,
        description: b[2] as String,
        ruleType: type,
        ruleValue: required,
        earned: earned,
      );
    }).toList(growable: false);
    return BadgeSnapshot(
      badges: badges,
      earnedCount: badges.where((b) => b.earned).length,
      totalCount: badges.length,
      newlyAwarded: const [],
    );
  }

  Future<BadgeSnapshot> getBadges() async {
    final json = await _client.getJson('/api/v1/badges');
    return BadgeSnapshot.fromJson(RepositoryParser.map(json));
  }
}
