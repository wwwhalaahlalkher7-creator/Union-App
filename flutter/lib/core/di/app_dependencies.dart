import '../../data/repositories/badges_repository.dart';
import '../../data/repositories/content_repository.dart';
import '../../data/repositories/eino_repository.dart';
import '../../data/repositories/interactions_repository.dart';
import '../../data/repositories/learning_events_repository.dart';
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
  late final LearningEventsRepository learningEvents;
  late final NotificationsRepository notifications;
  late final ScheduleRepository schedule;
  late final XpRepository xp;
  late final BadgesRepository badges;
  late final EinoRepository eino;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    authStorage = await AuthStorage.create();
    apiClient = ApiClient(
      baseUrl: AppConstants.apiBaseUrl,
      authStorage: authStorage,
    );
    content = ContentRepository(apiClient);
    student = StudentRepository(apiClient);
    materials = MaterialsRepository(apiClient);
    progress = ProgressRepository(apiClient);
    interactions = InteractionsRepository(apiClient);
    learningEvents = LearningEventsRepository(apiClient);
    notifications = NotificationsRepository(apiClient);
    schedule = ScheduleRepository(apiClient);
    xp = XpRepository(apiClient);
    badges = BadgesRepository(apiClient);
    eino = EinoRepository(apiClient);
    _initialized = true;
  }

  void dispose() {
    if (!_initialized) return;
    apiClient.dispose();
    _initialized = false;
    _instance = AppDependencies._();
  }
}
