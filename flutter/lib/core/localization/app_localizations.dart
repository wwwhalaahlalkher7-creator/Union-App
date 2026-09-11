import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';



class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
  ];

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    _AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const _values = <String, Map<String, String>>{
    'ar': {
      'appName': 'رابطة كلية الهندسة والعمارة',
      'welcome': 'مرحبًا بك 👋',
      'homeSubtitle': 'كل ما يخص الكلية والرابطة في مكان واحد.',
      'home': 'الرئيسية',
      'einoWelcome': 'أنا Eino، مساعدك الذكي داخل تطبيق الرابطة. اسألني عن الدراسة أو التطبيق أو أي موضوع عام.',
      'einoHint': 'اكتب رسالتك إلى Eino...',
      'einoHomeSubtitle': 'مساعد ذكي للدراسة والرابطة والأسئلة العامة.',
      'schedule': 'الجدول',
      'department': 'القسم',
      'semester': 'السمستر',
      'scheduleEmpty': 'لا توجد حصص منشورة لهذا الاختيار حاليًا.',
      'materials': 'المواد',
      'more': 'المزيد',
      'news': 'الأخبار',
      'announcements': 'الإعلانات',
      'activities': 'الأنشطة',
      'achievements': 'الإنجازات',
      'favorites': 'المفضلة',
      'recent': 'آخر ما تم فتحه',
      'mostUsed': 'الأكثر استخدامًا',
      'downloads': 'التنزيلات',
      'notifications': 'الإشعارات',
      'settings': 'الإعدادات',
      'about': 'عن الرابطة',
      'student': 'حساب الطالب',
      'studentOptional': 'تسجيل الطالب اختياري وسيُفعل لاحقًا.',
      'guest': 'الوضع كزائر',
      'appearance': 'المظهر',
      'language': 'اللغة',
      'system': 'النظام',
      'light': 'فاتح',
      'dark': 'داكن',
      'latestNews': 'آخر الأخبار',
      'latestAnnouncement': 'آخر إعلان',
      'continueLearning': 'متابعة التعلم',
      'seeMore': 'عرض المزيد',
      'connection': 'حالة الخدمات',
      'connected': 'متصل',
      'connectionFailed': 'تعذر الاتصال بالخدمة حاليًا',
      'checkConnection': 'اضغط للتحقق من الاتصال',
      'noData': 'لا توجد بيانات حاليًا.',
      'notReady': 'هذه الخدمة غير متاحة بعد.',
      'arabic': 'العربية',
      'english': 'English',
      'french': 'Français',
      'offline': 'غير متصل',
      'error': 'حدث خطأ',
      'refresh': 'تحديث',
      'lockedMaterials': 'المواد والجدول متاحان بعد تسجيل الطالب.',
    },
    'en': {
      'appName': 'Faculty of Engineering & Architecture Association',
      'welcome': 'Welcome 👋',
      'homeSubtitle': 'Everything you need from the faculty and association in one place.',
      'home': 'Home',
      'einoWelcome': 'I’m Eino, the smart assistant inside the association app. Ask about study, the app, or general topics.',
      'einoHint': 'Message Eino...',
      'einoHomeSubtitle': 'A smart assistant for study, the association, and general questions.',
      'schedule': 'Schedule',
      'department': 'Department',
      'semester': 'Semester',
      'scheduleEmpty': 'No published classes are available for this selection.',
      'materials': 'Materials',
      'more': 'More',
      'news': 'News',
      'announcements': 'Announcements',
      'activities': 'Activities',
      'achievements': 'Achievements',
      'favorites': 'Favorites',
      'recent': 'Recently opened',
      'mostUsed': 'Most used',
      'downloads': 'Downloads',
      'notifications': 'Notifications',
      'settings': 'Settings',
      'about': 'About',
      'student': 'Student account',
      'studentOptional': 'Student sign-in is optional and will be enabled later.',
      'guest': 'Guest mode',
      'appearance': 'Appearance',
      'language': 'Language',
      'system': 'System',
      'light': 'Light',
      'dark': 'Dark',
      'latestNews': 'Latest news',
      'latestAnnouncement': 'Latest announcement',
      'continueLearning': 'Continue learning',
      'seeMore': 'See more',
      'connection': 'Service status',
      'connected': 'Connected',
      'connectionFailed': 'The service is currently unavailable',
      'checkConnection': 'Tap to check the connection',
      'noData': 'No data available right now.',
      'notReady': 'This service is not available yet.',
      'arabic': 'العربية',
      'english': 'English',
      'french': 'Français',
      'offline': 'Offline',
      'error': 'Something went wrong',
      'refresh': 'Refresh',
      'lockedMaterials': 'Materials and schedule are available after student sign-in.',
    },
    'fr': {
      'appName': 'Association de la Faculté d’Ingénierie et d’Architecture',
      'welcome': 'Bienvenue 👋',
      'homeSubtitle': 'Tout ce qui concerne la faculté et l’association au même endroit.',
      'home': 'Accueil',
      'einoWelcome': 'Je suis Eino, l’assistant intelligent de l’application. Posez vos questions sur les études, l’association ou des sujets généraux.',
      'einoHint': 'Écrivez à Eino...',
      'einoHomeSubtitle': 'Un assistant intelligent pour les études, l’association et les questions générales.',
      'schedule': 'Emploi du temps',
      'department': 'Département',
      'semester': 'Semestre',
      'scheduleEmpty': 'Aucun cours publié pour cette sélection.',
      'materials': 'Supports',
      'more': 'Plus',
      'news': 'Actualités',
      'announcements': 'Annonces',
      'activities': 'Activités',
      'achievements': 'Réalisations',
      'favorites': 'Favoris',
      'recent': 'Récemment ouverts',
      'mostUsed': 'Les plus utilisés',
      'downloads': 'Téléchargements',
      'notifications': 'Notifications',
      'settings': 'Paramètres',
      'about': 'À propos',
      'student': 'Compte étudiant',
      'studentOptional': 'La connexion étudiant est facultative et sera activée plus tard.',
      'guest': 'Mode invité',
      'appearance': 'Apparence',
      'language': 'Langue',
      'system': 'Système',
      'light': 'Clair',
      'dark': 'Sombre',
      'latestNews': 'Dernières actualités',
      'latestAnnouncement': 'Dernière annonce',
      'continueLearning': 'Continuer l’apprentissage',
      'seeMore': 'Voir plus',
      'connection': 'État du service',
      'connected': 'Connecté',
      'connectionFailed': 'Service actuellement indisponible',
      'checkConnection': 'Touchez pour vérifier la connexion',
      'noData': 'Aucune donnée disponible pour le moment.',
      'notReady': 'Ce service n’est pas encore disponible.',
      'arabic': 'العربية',
      'english': 'English',
      'french': 'Français',
      'offline': 'Hors ligne',
      'error': 'Une erreur est survenue',
      'refresh': 'Actualiser',
      'lockedMaterials': 'Les supports et l’emploi du temps sont disponibles après connexion.',
    },
  };

  String t(String key) =>
      _values[locale.languageCode]?[key] ?? _values['ar']![key] ?? key;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales
          .any((supported) => supported.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
