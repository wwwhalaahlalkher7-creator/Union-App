/**
 * Canonical API error catalog.
 *
 * Keep public error codes stable. Clients can map these codes to localized
 * messages while the Worker remains responsible for safe Arabic defaults.
 */
export const API_ERRORS = Object.freeze({
  NOT_FOUND: ['المسار أو المورد المطلوب غير موجود.', 404],
  FORBIDDEN: ['ليس لديك صلاحية لتنفيذ هذا الإجراء.', 403],
  AUTH_REQUIRED: ['تسجيل الدخول مطلوب.', 401],
  AUTH_INVALID: ['الجلسة غير صالحة أو منتهية. سجّل الدخول مجددًا.', 401],
  CONFLICT: ['البيانات موجودة بالفعل أو تتعارض مع سجل موجود.', 409],
  RATE_LIMITED: ['تم تجاوز الحد المسموح مؤقتًا. حاول لاحقًا.', 429],
  INTERNAL_ERROR: ['حدث خطأ غير متوقع. حاول مرة أخرى.', 500],
  INVALID_REQUEST: ['البيانات المرسلة غير صالحة.', 400],
  DATA_CONSTRAINT: ['البيانات المرسلة لا تتوافق مع القيود الحالية.', 400],
});

export function errorResponse(errorFactory, ctx, code, overrides = {}) {
  const [defaultMessage, defaultStatus] =
    API_ERRORS[code] ?? API_ERRORS.INTERNAL_ERROR;
  return errorFactory(
    code,
    overrides.message ?? defaultMessage,
    overrides.status ?? defaultStatus,
    ctx.requestId,
    ctx.cors,
    overrides.details ?? null,
  );
}
