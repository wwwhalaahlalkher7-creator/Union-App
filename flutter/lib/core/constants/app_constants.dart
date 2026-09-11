class AppConstants {
  AppConstants._();

  static const appName = 'رابطة كلية الهندسة والعمارة';
  static const appNameEnglish = 'Faculty of Engineering & Architecture Association';

  // Unified API gateway. Flutter never talks to legacy providers directly.
  static const apiBaseUrl = String.fromEnvironment(
    'ASSOCIATION_API_BASE_URL',
    defaultValue:
        'https://leo-association-api.www-halaahlalkher7.workers.dev',
  );

  static const healthAction = 'health';
  static const newsAction = 'news';
  static const announcementsAction = 'announcements';
  static const activitiesAction = 'activities';
  static const achievementsAction = 'achievements';
  static const materialsAction = 'materials';
  static const scheduleAction = 'schedule';
  static const einoAction = 'eino';
}
