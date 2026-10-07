import '../../core/network/api_client.dart';
import '../models/xp_snapshot.dart';

class XpRepository {
  XpRepository(this._client);

  final ApiClient _client;

  Future<XpSnapshot> getXp() async {
    try {
      final json = await _client.getJson('/api/v1/xp', forceRefresh: true);
      final data = json['data'];
      if (data is! Map) {
        throw const ApiException('Invalid XP response.', code: 'INVALID_RESPONSE', kind: ApiErrorKind.response);
      }
      return XpSnapshot.fromJson(Map<String, dynamic>.from(data));
    } catch (primaryError) {
      // Keep the XP page usable if an older/deployed Worker is temporarily
      // missing the aggregate /xp response. The student stats endpoint is
      // already part of the student contract and contains the authoritative
      // total XP/level.
      try {
        final json = await _client.getJson(
          '/api/v1/student/stats',
          forceRefresh: true,
        );
        final raw = json['data'];
        final stats = raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
        final total = int.tryParse(
              '${stats['xp_total'] ?? stats['xpTotal'] ?? 0}',
            ) ??
            0;
        final level = int.tryParse('${stats['level'] ?? 1}') ?? 1;
        final start = 100 * (level - 1);
        return XpSnapshot(
          totalXp: total,
          level: level,
          levelXp: (total - start).clamp(0, 100),
          nextLevelXp: 100,
        );
      } catch (_) {
        // Preserve the original, more useful API/network error.
        if (primaryError is ApiException) rethrow;
        throw ApiException(
          'Could not load XP data.',
          code: 'XP_UNAVAILABLE',
          cause: primaryError,
          kind: primaryError is ApiException ? primaryError.kind : ApiErrorKind.client,
          retryable: true,
        );
      }
    }
  }
}
