import '../../data/repositories/badges_repository.dart';
import '../../data/repositories/content_repository.dart';
import '../../data/repositories/eino_repository.dart';
import '../../data/repositories/general_chat_repository.dart';
import '../../data/repositories/feedback_repository.dart';
import '../../data/repositories/interactions_repository.dart';
import '../../data/repositories/materials_repository.dart';
import '../../data/repositories/notifications_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../data/repositories/student_repository.dart';
import '../../data/repositories/xp_repository.dart';
import '../constants/app_constants.dart';
import '../network/api_client.dart';
import '../storage/auth_storage.dart';

/// Application-wide dependency container.
///
/// Dependencies are created once at startup and disposed together with the
/// application. Feature screens use these stable instances rather than
/// creating network clients in lifecycle callbacks.
final class AppDependencies {
  AppDependencies._();

  static AppDependencies _instance = AppDependencies._();

  static AppDependencies get instance => _instance;

  late final AuthStorage authStorage;
  late final ApiClient apiClient;
  late final ContentRepository content;
  late final StudentRepository student;
  late final MaterialsRepository materials;
  late final ProgressRepository progress;
  late final InteractionsRepository interactions;
  late final NotificationsRepository notifications;
  late final ScheduleRepository schedule;
  late final XpRepository xp;
  late final BadgesRepository badges;
  late final EinoRepository eino;
  late final GeneralChatRepository generalChat;
  late final FeedbackRepository feedback;

  bool _initialized = false;
  ApiClient? _clientDuringInitialization;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      authStorage = await AuthStorage.create();
      final client = ApiClient(
        baseUrl: AppConstants.apiBaseUrl,
        authStorage: authStorage,
      );
      _clientDuringInitialization = client;
      apiClient = client;
      content = ContentRepository(client);
      student = StudentRepository(client);
      materials = MaterialsRepository(client);
      progress = ProgressRepository(client);
      interactions = InteractionsRepository(client);
      notifications = NotificationsRepository(client);
      schedule = ScheduleRepository(client);
      xp = XpRepository(client);
      badges = BadgesRepository(client);
      eino = EinoRepository(client);
      generalChat = GeneralChatRepository(client);
      feedback = FeedbackRepository(client);
      _initialized = true;
      _clientDuringInitialization = null;
    } catch (_) {
      // Some late fields may have been assigned before a constructor failed.
      // Replace the entire singleton rather than retrying on a half-built one.
      _clientDuringInitialization?.dispose();
      _clientDuringInitialization = null;
      if (identical(_instance, this)) _instance = AppDependencies._();
      rethrow;
    }
  }

  void dispose() {
    if (_initialized) {
      apiClient.dispose();
    } else {
      _clientDuringInitialization?.dispose();
    }
    _clientDuringInitialization = null;
    _initialized = false;
    if (identical(_instance, this)) _instance = AppDependencies._();
  }
}
