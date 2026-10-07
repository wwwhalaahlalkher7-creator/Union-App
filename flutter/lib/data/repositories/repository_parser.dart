import '../../core/errors/app_error.dart';

/// Shared payload parsing helpers used by repositories.
///
/// Repositories should validate API boundaries here instead of silently
/// converting malformed responses into empty data structures.
final class RepositoryParser {
  const RepositoryParser._();

  static Map<String, dynamic> map(
    Map<String, dynamic> response, {
    String key = 'data',
    String code = 'INVALID_RESPONSE',
  }) {
    final value = response[key];
    if (value is Map) return Map<String, dynamic>.from(value);
    throw ApiException(
      'Invalid server response.',
      code: code,
      kind: ApiErrorKind.response,
    );
  }

  static List<dynamic> list(
    Map<String, dynamic> response, {
    String key = 'data',
    String code = 'INVALID_RESPONSE',
  }) {
    final value = response[key];
    if (value is List) return value;
    throw ApiException(
      'Invalid server response.',
      code: code,
      kind: ApiErrorKind.response,
    );
  }

  static List<Map<String, dynamic>> maps(
    Map<String, dynamic> response, {
    String key = 'data',
    String code = 'INVALID_RESPONSE',
  }) {
    return list(response, key: key, code: code)
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }

  static int integer(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
