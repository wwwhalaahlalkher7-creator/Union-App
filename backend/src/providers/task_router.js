const AR = /[\u0600-\u06FF]/;
const LIVE = /(اليوم|الآن|حالي(?:اً|ا)|آخر|اخر|حديث|جديد|جديده|جديدة|الأخبار|الاخبار|خبر|أخبار|اخبار|محدث|محدثة|مصدر|المصادر|ابحث|بحث|what's new|latest|today|now|current|recent|news|search|source)/i;
const APP = /(TRINEX|إينو|اينو|التطبيق|التطبيقات|الإعدادات|الاعدادات|لوحة التحكم|المواد|الجدول|الشارات|XP|الإشعارات|الاشعارات|تسجيل الدخول|كلمة السر)/i;
const MATERIAL = /(مادة‏?|المادة|مواد دراسية|المواد الدراسية|ملف المادة|ملزمة|ملزمة|محاضرة|lecture|course material|study material)/i;
const STUDY = /(اشرح|فسر|حل|مسألة|سؤال|مفهوم|تعريف|قانون|نظرية|دراسة|دراسي|واجب|امتحان|اختبار|quiz|explain|solve|concept|theory|study|homework|exam)/i;
const REASON = /(قارن|حلل|حلّل|استنتج|استدلال|لماذا|برهن|أثبت|اثبت|ناقش|قيّم|قيم|صمّم|صمم|derive|reason|reasoning|analy[sz]e|compare|prove|evaluate|design)/i;

export function classifyTextTask({ message = '', context = '', requestedTask = '' } = {}) {
  const explicit = String(requestedTask || '').trim().toLowerCase();
  if (['chat','academic','reasoning','app','material','summary','web-search','research'].includes(explicit)) return explicit;
  const text = `${message}\n${context}`;
  if (LIVE.test(message)) return /بحث عميق|بحث أكاديمي|research|academic search|deep research/i.test(message) ? 'research' : 'web-search';
  if (message.length > 4500 || /لخص|لخّص|تلخيص|summary|summarize/i.test(message)) return 'summary';
  if (MATERIAL.test(message)) return 'material';
  if (APP.test(message)) return 'app';
  if (REASON.test(message)) return 'reasoning';
  if (STUDY.test(message)) return 'academic';
  return 'chat';
}

export function textRouteOrder(task) {
  switch (task) {
    case 'academic': return ['mistral','gemini','groq','free.ai'];
    case 'reasoning': return ['mistral','gemini','groq','free.ai'];
    case 'app': return ['mistral','gemini','groq','free.ai'];
    case 'material': return ['mistral','gemini','groq','free.ai'];
    case 'summary': return ['gemini','mistral','groq','free.ai'];
    case 'web-search':
    case 'research': return ['gemini','mistral','groq','free.ai'];
    case 'chat':
    default: return ['groq','mistral','gemini','free.ai'];
  }
}

export function taskIsArabic(text) { return AR.test(String(text || '')); }
