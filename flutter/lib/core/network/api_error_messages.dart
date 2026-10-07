/// Stable, user-safe fallback messages for network-layer failures.
///
/// These messages are deliberately kept outside [ApiClient] so transport,
/// decoding and authentication code can reuse the same wording.
class ApiErrorMessages {
  const ApiErrorMessages._();

  static const offline = 'No internet connection. Check your connection and try again.';
  static const timeout = 'The service request timed out. Please try again.';
  static const fileTimeout = 'File processing timed out. Please try again.';
  static const server = 'The server returned an error. Please try again.';
  static const requestFailed = 'The request could not be completed.';
  static const invalidResponse = 'Invalid server response.';
}
