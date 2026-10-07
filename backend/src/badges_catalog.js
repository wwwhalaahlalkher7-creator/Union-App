// Immutable student badge catalogue. Badge definitions are application-owned and are not configurable from the admin dashboard.
export const BADGE_CATALOG = Object.freeze([
  ['badge-first-step','البداية','ابدأ أول تقدم دراسي موثق.','progress_events',1,10],
  ['badge-five-progress','خطوة ثابتة','سجّل 5 عمليات تقدم دراسي.','progress_events',5,20],
  ['badge-ten-progress','مواظب','سجّل 10 عمليات تقدم دراسي.','progress_events',10,30],
  ['badge-twentyfive-progress','متابع قوي','سجّل 25 عملية تقدم دراسي.','progress_events',25,40],
  ['badge-fifty-progress','لا تتوقف','سجّل 50 عملية تقدم دراسي.','progress_events',50,50],
  ['badge-hundred-progress','مئة خطوة','سجّل 100 عملية تقدم دراسي.','progress_events',100,60],
  ['badge-quarter-thousand-progress','ربع ألف','سجّل 250 عملية تقدم دراسي.','progress_events',250,70],
  ['badge-first-complete','أول إنجاز','أكمل أول ملف دراسي.','completed_materials',1,100],
  ['badge-three-complete','ثلاثة ملفات','أكمل 3 ملفات دراسية.','completed_materials',3,110],
  ['badge-five-complete','خمسة ملفات','أكمل 5 ملفات دراسية.','completed_materials',5,120],
  ['badge-ten-complete','عشرة ملفات','أكمل 10 ملفات دراسية.','completed_materials',10,130],
  ['badge-twenty-complete','عشرون ملفًا','أكمل 20 ملفًا دراسيًا.','completed_materials',20,140],
  ['badge-thirty-complete','ثلاثون ملفًا','أكمل 30 ملفًا دراسيًا.','completed_materials',30,150],
  ['badge-fifty-complete','موسوعة','أكمل 50 ملفًا دراسيًا.','completed_materials',50,160],
  ['badge-first-subject','أول مادة','أكمل مادة دراسية واحدة.','completed_subjects',1,200],
  ['badge-three-subjects','متعدد المواد','أكمل مواد من 3 مقررات مختلفة.','completed_subjects',3,210],
  ['badge-five-subjects','واسع المعرفة','أكمل مواد من 5 مقررات مختلفة.','completed_subjects',5,220],
  ['badge-eight-subjects','جامع المقررات','أكمل مواد من 8 مقررات مختلفة.','completed_subjects',8,230],
  ['badge-xp-50','أول دفعة','اجمع 50 XP.','xp_total',50,300],
  ['badge-xp-100','مئة XP','اجمع 100 XP.','xp_total',100,310],
  ['badge-xp-250','ربع ألف XP','اجمع 250 XP.','xp_total',250,320],
  ['badge-xp-500','500 XP','اجمع 500 XP.','xp_total',500,330],
  ['badge-xp-1000','1000 XP','اجمع 1000 XP.','xp_total',1000,340],
  ['badge-xp-2000','2000 XP','اجمع 2000 XP.','xp_total',2000,350],
  ['badge-xp-5000','5000 XP','اجمع 5000 XP.','xp_total',5000,360],
  ['badge-level-2','المستوى 2','وصل إلى المستوى الثاني.','level',2,400],
  ['badge-level-3','المستوى 3','وصل إلى المستوى الثالث.','level',3,410],
  ['badge-level-5','المستوى 5','وصل إلى المستوى الخامس.','level',5,420],
  ['badge-level-10','المستوى 10','وصل إلى المستوى العاشر.','level',10,430],
  ['badge-level-15','المستوى 15','وصل إلى المستوى الخامس عشر.','level',15,440],
  ['badge-first-event','أول حدث','أكمل أول حدث تعليمي.','learning_events',1,500],
  ['badge-five-events','محب التعلم','أكمل 5 أحداث تعليمية.','learning_events',5,510],
  ['badge-ten-events','صانع العادة','أكمل 10 أحداث تعليمية.','learning_events',10,520],
  ['badge-first-comment','صوتك مهم','اكتب أول تعليق ظاهر.','comments',1,600],
  ['badge-five-comments','مشارك','اكتب 5 تعليقات ظاهرة.','comments',5,610],
  ['badge-ten-comments','حوار مستمر','اكتب 10 تعليقات ظاهرة.','comments',10,620],
  ['badge-first-reaction','تفاعل أول','أضف أول تفاعل.','reactions',1,630],
  ['badge-ten-reactions','متفاعل','أضف 10 تفاعلات.','reactions',10,640],
  ['badge-first-reply','مجيب','اكتب أول رد على تعليق.','replies',1,650],
  ['badge-five-replies','حوار بنّاء','اكتب 5 ردود على التعليقات.','replies',5,660],
]);

export const BADGE_CATEGORIES = Object.freeze([
  { key: 'xp_total', name_ar: 'XP', icon: 'bolt', unlimited: true },
  { key: 'level', name_ar: 'المستويات', icon: 'trending_up', unlimited: true },
  { key: 'completed_materials', name_ar: 'المواد الدراسية', icon: 'menu_book', unlimited: false, max: 50 },
  { key: 'completed_subjects', name_ar: 'المقررات', icon: 'school', unlimited: false, max: 50 },
  { key: 'progress_events', name_ar: 'التقدم الدراسي', icon: 'auto_stories', unlimited: true },
  { key: 'learning_events', name_ar: 'الأحداث التعليمية', icon: 'event', unlimited: true },
  { key: 'comments', name_ar: 'التعليقات', icon: 'comment', unlimited: true },
  { key: 'reactions', name_ar: 'التفاعلات', icon: 'thumb_up', unlimited: true },
  { key: 'replies', name_ar: 'الردود', icon: 'reply', unlimited: true },
]);

function dynamicXpRows(current) {
  const fixed = BADGE_CATALOG.filter(row => row[3] === 'xp_total');
  const maxFixed = Math.max(...fixed.map(row => Number(row[4])));
  const rows = [...fixed];
  let threshold = maxFixed * 2;
  let order = Math.max(...fixed.map(row => Number(row[5]))) + 10;
  while (threshold <= Math.max(current, maxFixed) * 2 && threshold <= 100000000) {
    rows.push([`badge-xp-${threshold}`, `${threshold} XP`, `اجمع ${threshold} XP.`, 'xp_total', threshold, order]);
    threshold *= 2;
    order += 10;
  }
  return rows;
}

export function badgeRows(currentXp = 0) {
  const base = BADGE_CATALOG.filter(row => row[3] !== 'xp_total');
  return [...base, ...dynamicXpRows(Number(currentXp) || 0)].map(([id,name_ar,description_ar,rule_type,rule_value,sort_order]) => ({
    id, name_ar, description_ar, icon_url: null, rule_type, rule_value, active: 1, sort_order,
  }));
}

export function badgeCategoryRows(values) {
  const definitions = badgeRows(Number(values?.xp_total || 0));
  return BADGE_CATEGORIES.map((category) => {
    const current = Math.max(0, Number(values?.[category.key] || 0));
    const candidates = definitions.filter(b => b.rule_type === category.key).sort((a,b) => Number(a.rule_value) - Number(b.rule_value));
    const earned = candidates.filter(b => Number(b.rule_value) <= current);
    let next = candidates.find(b => Number(b.rule_value) > current) || null;
    if (!next && category.unlimited) {
      const last = candidates[candidates.length - 1];
      const nextValue = Math.max(current + 1, Number(last?.rule_value || 1) * 2);
      next = { id: `badge-${category.key}-${nextValue}`, name_ar: `${nextValue}`, description_ar: `الوصول إلى ${nextValue}.`, icon_url: null, rule_type: category.key, rule_value: nextValue, active: 1, sort_order: 999999 };
    }
    const max = category.max || null;
    const complete = max != null && current >= max;
    return {
      key: category.key, name_ar: category.name_ar, icon: category.icon, unlimited: category.unlimited, max, current,
      earnedCount: earned.length, completed: complete, next: complete ? null : next,
    };
  }).filter(category => category.next || category.earnedCount > 0 || category.completed);
}
