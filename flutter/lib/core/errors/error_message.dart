import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import 'app_error.dart';

/// Converts technical exceptions into messages safe and useful for users.
///
/// Keep this mapping in one place so individual screens do not duplicate
/// `catch` logic or expose implementation details.
class ErrorMessage {
  const ErrorMessage._();

  static String from(
    BuildContext context,
    Object error, {
    String? fallbackKey,
  }) {
    final l10n = AppLocalizations.of(context);

    if (error is ApiException) {
      final code = error.code?.toUpperCase();
      final key = _keyForCode(code) ?? _keyForKind(error.kind);
      if (key != null) {
        return l10n.t(key);
      }

      // Server-provided messages are already sanitized by ApiClient.
      if (error.message.trim().isNotEmpty) return error.message;
    }

    if (fallbackKey != null) return l10n.t(fallbackKey);
    return l10n.t('genericError');
  }

  static String? _keyForCode(String? code) => switch (code) {
        'AUTH_REQUIRED' ||
        'AUTH_INVALID' ||
        'AUTH_INVALID_CREDENTIALS' ||
        'STUDENT_AUTH_REQUIRED' ||
        'STAFF_AUTH_REQUIRED' => 'sessionExpired',
        'AUTH_RATE_LIMITED' || 'AUTH_LOCKED' => 'tooManyAttempts',
        'EMAIL_INVALID' => 'invalidEmail',
        'EMAIL_ALREADY_IN_USE' => 'emailAlreadyUsed',
        'ACCOUNT_ALREADY_REGISTERED' => 'accountAlreadyRegistered',
        'STUDENT_NOT_FOUND' => 'studentNotFound',
        'SEMESTER_NOT_FOUND' => 'semesterNotFound',
        'MATERIAL_NOT_FOUND' ||
        'MATERIAL_FILE_UNAVAILABLE' => 'openMaterialUnavailable',
        'NOT_FOUND' => 'notFound',
        'FORBIDDEN' => 'permissionDenied',
        'CONFLICT' => 'conflict',
        'RATE_LIMITED' => 'tooManyAttempts',
        'EINO_PROVIDER_LIMITED' ||
        'EINO_RATE_LIMITED' ||
        'EINO_DAILY_LIMITED' ||
        'EINO_GLOBAL_LIMITED' => 'einoRateLimited',
        'EINO_PROVIDER_AUTH' => 'einoProviderAuth',
        'EINO_PROVIDER_ROUTE' => 'einoProviderRoute',
        'EINO_PROVIDER_ERROR' => 'einoProviderUnavailable',
        'EINO_TIMEOUT' => 'einoTimeout',
        _ => null,
      };

  static String? _keyForKind(ApiErrorKind kind) => switch (kind) {
        ApiErrorKind.offline => 'offlineConnectionError',
        ApiErrorKind.timeout => 'requestTimeout',
        ApiErrorKind.server => 'serverError',
        ApiErrorKind.auth => 'sessionExpired',
        _ => null,
      };
}
