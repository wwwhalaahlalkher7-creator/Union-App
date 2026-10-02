import {
  headers, json, ok, databaseErrorResponse, error, parseJson, clampInt, queryAll, queryOne, rowMap,
  parseJsonValue, currentQuotaMonth, bearer, sha256, token, pbkdf2Hash, timingSafeEqualHex, makeId, sqlValue, positiveInt,
  PUBLIC_MAX, AUTH_ACCESS_TTL, AUTH_REFRESH_TTL, AUTH_MAX_FAILED, AUTH_LOCK_SECONDS, AUTH_IP_WINDOW_SECONDS,
  AUTH_IP_LOGIN_LIMIT, AUTH_IP_REFRESH_LIMIT, PBKDF2_ITERATIONS, XP_DAILY_CAP, XP_LEVEL_BASE,
  EINO_MAX_MESSAGE, EINO_MAX_CONTEXT, EINO_WINDOW_SECONDS, EINO_WINDOW_LIMIT,
  EINO_STUDENT_DAILY_LIMIT_DEFAULT, EINO_GUEST_DAILY_LIMIT_DEFAULT, EINO_GLOBAL_DAILY_LIMIT_DEFAULT,
  R2_MAX_OBJECT_BYTES, R2_MAX_STORAGE_BYTES, R2_MAX_CLASS_A_MONTHLY, R2_MAX_UPLOAD_FILES_PER_REQUEST, R2_ALLOWED_TYPES,
  normalizeEmail, isValidEmail,
} from './core.js';
export async function auth(ctx, required = true) {
  // Base session lookup deliberately touches ONLY the sessions table.
  // Student and staff identity data are loaded by their respective guards below.
  const raw = bearer(ctx.request);
  if (!raw) return required ? { response: error('AUTH_REQUIRED', 'تسجيل الدخول مطلوب.', 401, ctx.requestId, ctx.cors) } : null;
  const hash = await sha256(raw);
  const row = await queryOne(ctx.env, `SELECT * FROM sessions WHERE access_token_hash = ? AND revoked_at IS NULL AND expires_at > CURRENT_TIMESTAMP LIMIT 1`, hash);
  if (!row) return { response: error('AUTH_INVALID', 'الجلسة غير صالحة أو منتهية. سجّل الدخول مجددًا.', 401, ctx.requestId, ctx.cors) };
  if ((row.student_id == null) === (row.staff_user_id == null)) {
    console.error('Invalid session identity invariant', { sessionId: row.id });
    return { response: error('AUTH_INVALID', 'الجلسة غير صالحة. سجّل الدخول مجددًا.', 401, ctx.requestId, ctx.cors) };
  }
  return { session: row };
}

export async function studentAuth(ctx, required = true) {
  const a = await auth(ctx, required);
  if (!a) return null;
  if (a.response) return a;
  if (!a.session.student_id || a.session.staff_user_id) {
    return { response: error('STUDENT_AUTH_REQUIRED', 'جلسة طالب مطلوبة.', 403, ctx.requestId, ctx.cors) };
  }
  const student = await queryOne(ctx.env, `SELECT id AS student_id, student_number, full_name, department_id, current_semester_id, active AS student_active FROM students WHERE id = ? LIMIT 1`, a.session.student_id);
  if (!student || student.student_active !== 1) {
    return { response: error('STUDENT_AUTH_REQUIRED', 'حساب الطالب غير موجود أو غير فعال.', 403, ctx.requestId, ctx.cors) };
  }
  a.session = { ...a.session, ...student };
  return a;
}

export async function staffAuth(ctx, required = true) {
  const a = await auth(ctx, required);
  if (!a) return null;
  if (a.response) return a;
  if (!a.session.staff_user_id || a.session.student_id) {
    return { response: error('STAFF_AUTH_REQUIRED', 'جلسة موظف الإدارة مطلوبة.', 403, ctx.requestId, ctx.cors) };
  }
  const staff = await queryOne(ctx.env, `SELECT su.id AS staff_user_id, su.user_id AS staff_user_id_login, su.email AS staff_email, su.display_name AS staff_display_name, su.role_id AS staff_role_id, r.name AS staff_role_name, su.active AS staff_active FROM staff_users su JOIN roles r ON r.id = su.role_id WHERE su.id = ? LIMIT 1`, a.session.staff_user_id);
  if (!staff || staff.staff_active !== 1) {
    return { response: error('STAFF_AUTH_REQUIRED', 'حساب الإدارة غير موجود أو غير فعال.', 403, ctx.requestId, ctx.cors) };
  }
  a.session = { ...a.session, ...staff };
  return a;
}

export async function verifySecret(secret, hash, salt, algo) {
  if (!hash) return false;
  if ((algo || 'legacy-sha256') === 'legacy-sha256') return timingSafeEqualHex(await sha256(secret), hash);
  const derived = await pbkdf2Hash(secret, salt, PBKDF2_ITERATIONS);
  return timingSafeEqualHex(derived, hash);
}

export async function upgradeStudentHash(ctx, student, secret) {
  const salt = token(16);
  const hash = await pbkdf2Hash(secret, salt);
  await ctx.env.DB.prepare("UPDATE students SET auth_secret_hash = ?, auth_secret_salt = ?, auth_secret_algo = 'pbkdf2-sha256', failed_login_attempts = 0, locked_until = NULL, updated_at = CURRENT_TIMESTAMP WHERE id = ?")
    .bind(hash, salt, student.id).run();
}

export async function authIpRateLimit(ctx, action, limit, windowSeconds = AUTH_IP_WINDOW_SECONDS) {
  // Cloudflare supplies CF-Connecting-IP at the edge. Hash it before persistence so
  // the database never stores a raw client IP. The bucketed UPSERT is atomic in D1.
  const ip = ctx.request.headers.get('CF-Connecting-IP') || 'unknown';
  const ipHash = await sha256(ip);
  const bucket = Math.floor(Date.now() / (windowSeconds * 1000));
  const id = `${action}:${ipHash}:${bucket}`;
  const result = await ctx.env.DB.prepare(`
    INSERT INTO auth_rate_limits (id, ip_hash, action, window_started_at, count)
    VALUES (?, ?, ?, datetime(?, 'unixepoch'), 1)
    ON CONFLICT(id) DO UPDATE SET count = count + 1
  `).bind(id, ipHash, action, bucket * windowSeconds).run();
  if (!result.success) return { allowed: false, retryAfterSeconds: windowSeconds };
  const row = await queryOne(ctx.env, 'SELECT count FROM auth_rate_limits WHERE id=?', id);
  const count = Number(row?.count || 0);
  return { allowed: count <= limit, retryAfterSeconds: windowSeconds - (Math.floor(Date.now() / 1000) % windowSeconds) };
}

export async function recordAuthEvent(ctx, actorType, actorId, eventType) {
  try {
    const ip = ctx.request.headers.get('CF-Connecting-IP') || '';
    const ua = ctx.request.headers.get('User-Agent') || '';
    await ctx.env.DB.prepare('INSERT INTO auth_audit_events (id, actor_type, actor_id, event_type, ip_hash, user_agent_hash) VALUES (?, ?, ?, ?, ?, ?)')
      .bind(crypto.randomUUID(), actorType, actorId || null, eventType, await sha256(ip), await sha256(ua)).run();
  } catch (e) { console.error('auth audit failed', e); }
}

export function lockedResponse(ctx) {
  return error('AUTH_LOCKED', 'تم إيقاف محاولات تسجيل الدخول مؤقتًا بسبب محاولات فاشلة متكررة. حاول لاحقًا.', 429, ctx.requestId, ctx.cors);
}

export async function login(ctx) {
  const ipLimit = await authIpRateLimit(ctx, 'student_login', AUTH_IP_LOGIN_LIMIT);
  if (!ipLimit.allowed) return error('AUTH_RATE_LIMITED', 'تم تجاوز عدد محاولات تسجيل الدخول مؤقتًا. حاول لاحقًا.', 429, ctx.requestId, ctx.cors);
  const body = await parseJson(ctx.request);
  const identifier = String(body?.studentNumber || body?.identifier || body?.email || '').trim();
  const secret = String(body?.password || body?.verificationCode || '');
  if (!identifier || !secret || secret.length > 256) return error('AUTH_INPUT_INVALID', 'أدخل رقم الطالب أو البريد الإلكتروني وبيانات التحقق.', 400, ctx.requestId, ctx.cors);
  const student = await queryOne(ctx.env, 'SELECT * FROM students WHERE (student_number = ? OR (email IS NOT NULL AND lower(email) = ?)) AND active = 1 LIMIT 1', identifier, identifier.toLowerCase());
  if (!student || !student.auth_secret_hash) return error('AUTH_INVALID_CREDENTIALS', 'بيانات تسجيل الدخول غير صحيحة.', 401, ctx.requestId, ctx.cors);
  if (student.locked_until && new Date(student.locked_until).getTime() > Date.now()) return lockedResponse(ctx);
  const valid = await verifySecret(secret, student.auth_secret_hash, student.auth_secret_salt, student.auth_secret_algo);
  if (!valid) {
    // Increment the failure counter in SQL so concurrent wrong-password requests
    // cannot overwrite each other's count (read-then-write race).
    await ctx.env.DB.prepare(`
      UPDATE students
      SET failed_login_attempts = failed_login_attempts + 1,
          locked_until = CASE
            WHEN failed_login_attempts + 1 >= ?
              THEN datetime('now', '+' || ? || ' seconds')
            ELSE locked_until
          END,
          updated_at = CURRENT_TIMESTAMP
      WHERE id = ? AND active = 1
    `).bind(AUTH_MAX_FAILED, AUTH_LOCK_SECONDS, student.id).run();
    const state = await queryOne(ctx.env, 'SELECT failed_login_attempts, locked_until FROM students WHERE id=?', student.id);
    const locked = Number(state?.failed_login_attempts || 0) >= AUTH_MAX_FAILED && state?.locked_until;
    await recordAuthEvent(ctx, 'student', student.id, locked ? 'login_locked' : 'login_failed');
    return locked ? lockedResponse(ctx) : error('AUTH_INVALID_CREDENTIALS', 'بيانات تسجيل الدخول غير صحيحة.', 401, ctx.requestId, ctx.cors);
  }
  if ((student.auth_secret_algo || 'legacy-sha256') === 'legacy-sha256') await upgradeStudentHash(ctx, student, secret);
  else await ctx.env.DB.prepare('UPDATE students SET failed_login_attempts = 0, locked_until = NULL WHERE id = ?').bind(student.id).run();
  await recordAuthEvent(ctx, 'student', student.id, 'login_success');
  return issueSession(ctx, { studentId: student.id });
}

export async function registerStudent(ctx) {
  const ipLimit = await authIpRateLimit(ctx, 'student_register', AUTH_IP_LOGIN_LIMIT);
  if (!ipLimit.allowed) return error('AUTH_RATE_LIMITED', 'تم تجاوز عدد محاولات التسجيل مؤقتًا. حاول لاحقًا.', 429, ctx.requestId, ctx.cors);
  const body = await parseJson(ctx.request);
  const studentNumber = String(body?.studentNumber || '').trim();
  const email = normalizeEmail(body?.email);
  const password = String(body?.password || '');
  const confirmPassword = String(body?.confirmPassword || '');
  const semesterId = String(body?.semesterId || '').trim();

  // The administration owns the student's identity (name, number and department).
  // During first registration the student chooses only their current semester,
  // email and password. The chosen semester is saved as the student's academic
  // preference and can later be changed by the student or administration.
  if (!studentNumber || !password || !semesterId) {
    return error('REGISTER_FIELDS_REQUIRED', 'الرقم الجامعي والفصل وكلمة المرور مطلوبة.', 400, ctx.requestId, ctx.cors);
  }
  if (email && !isValidEmail(email)) {
    return error('EMAIL_INVALID', 'يرجى إدخال بريد إلكتروني صالح.', 400, ctx.requestId, ctx.cors);
  }
  if (password.length < 8 || password.length > 256) {
    return error('PASSWORD_TOO_SHORT', 'كلمة المرور يجب ألا تقل عن 8 أحرف.', 400, ctx.requestId, ctx.cors);
  }
  if (confirmPassword && password !== confirmPassword) {
    return error('PASSWORDS_MISMATCH', 'كلمتا المرور غير متطابقتين.', 400, ctx.requestId, ctx.cors);
  }

  const student = await queryOne(ctx.env, `
    SELECT st.*, d.name_ar AS department_name, se.name_ar AS semester_name
    FROM students st
    LEFT JOIN departments d ON d.id = st.department_id
    LEFT JOIN semesters se ON se.id = st.current_semester_id
    WHERE st.student_number = ? AND st.active = 1
    LIMIT 1
  `, studentNumber);
  if (!student) {
    return error('STUDENT_NOT_FOUND', 'الرقم الجامعي غير مسجل في قيود الكلية. يرجى مراجعة إدارة الكلية.', 404, ctx.requestId, ctx.cors);
  }
  const selectedSemester = await queryOne(ctx.env, 'SELECT id FROM semesters WHERE id = ? AND active = 1 LIMIT 1', semesterId);
  if (!selectedSemester) {
    return error('SEMESTER_NOT_FOUND', 'الفصل الدراسي المحدد غير موجود أو غير نشط.', 400, ctx.requestId, ctx.cors);
  }
  if (student.auth_secret_hash) {
    return error('ACCOUNT_ALREADY_REGISTERED', 'هذا الحساب مسجل بالفعل. يمكنك تسجيل الدخول مباشرة.', 409, ctx.requestId, ctx.cors);
  }

  if (email) {
    const emailInUse = await queryOne(ctx.env, 'SELECT id FROM students WHERE lower(email) = ? AND id <> ? AND active = 1', email, student.id);
    if (emailInUse) {
      return error('EMAIL_ALREADY_IN_USE', 'البريد الإلكتروني مستخدم بالفعل لحساب طالب آخر.', 409, ctx.requestId, ctx.cors);
    }
  }

  const salt = token(16);
  const hash = await pbkdf2Hash(password, salt);

  // The NULL check makes registration safe under concurrent requests: only
  // the first request may claim the unregistered student record.
  const claimed = await ctx.env.DB.prepare(
    `UPDATE students
     SET email = ?, current_semester_id = ?, auth_secret_hash = ?, auth_secret_salt = ?, auth_secret_algo = 'pbkdf2-sha256',
         failed_login_attempts = 0, locked_until = NULL, updated_at = CURRENT_TIMESTAMP
     WHERE id = ? AND active = 1 AND auth_secret_hash IS NULL`
  ).bind(email || null, semesterId, hash, salt, student.id).run();

  if (!claimed.meta?.changes) {
    return error('ACCOUNT_ALREADY_REGISTERED', 'هذا الحساب مسجل بالفعل. يمكنك تسجيل الدخول مباشرة.', 409, ctx.requestId, ctx.cors);
  }

  await recordAuthEvent(ctx, 'student', student.id, 'register_success');
  return issueSession(ctx, { studentId: student.id });
}


async function sendStudentRecoveryEmail(ctx, email, code) {
  // Google Apps Script ContentService intentionally returns a 3xx redirect to
  // a one-time script.googleusercontent.com URL. A normal fetch with
  // redirect:'follow' may convert a POST into a GET when following a 302,
  // which makes Apps Script run doGet() instead of doPost(). Follow the
  // redirect manually so the original POST body and method are preserved.
  const endpoint = String(ctx.env.GOOGLE_APPS_SCRIPT_URL || '').trim();
  const emailToken = String(ctx.env.GOOGLE_APPS_SCRIPT_EMAIL_TOKEN || '').trim();
  const recipient = normalizeEmail(email);
  if (!endpoint || !emailToken) return { ok: false, reason: 'CONFIG' };
  if (!isValidEmail(recipient)) return { ok: false, reason: 'INVALID_EMAIL' };

  const requestBody = JSON.stringify({
    action: 'sendRecoveryEmail',
    token: emailToken,
    to: recipient,
    code,
  });
  const requestOptions = {
    method: 'POST',
    redirect: 'manual',
    headers: { 'content-type': 'application/json; charset=utf-8', accept: 'application/json' },
    body: requestBody,
  };

  function safeResponseText(value) {
    return String(value || '')
      .slice(0, 500)
      .replace(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi, '[redacted-email]');
  }

  async function readResponse(response) {
    const text = await response.text();
    let data = null;
    try { data = JSON.parse(text); } catch (_) {}
    return { response, text, data };
  }

  try {
    let result = await readResponse(await fetch(endpoint, requestOptions));
    let redirects = 0;

    while (result.response.status >= 300 && result.response.status < 400 && redirects < 2) {
      const location = result.response.headers.get('Location');
      if (!location) {
        console.error('recovery email adapter redirect missing Location', { status: result.response.status });
        return { ok: false, reason: 'REDIRECT_MISSING_LOCATION' };
      }
      redirects += 1;
      const redirectedUrl = new URL(location, endpoint).toString();
      result = await readResponse(await fetch(redirectedUrl, requestOptions));
    }

    const safeText = safeResponseText(result.text);
    console.log('recovery email adapter', {
      status: result.response.status,
      ok: result.response.ok,
      redirects,
      response: safeText,
    });

    if (!result.response.ok) return { ok: false, reason: 'HTTP_ERROR', status: result.response.status, detail: safeText };
    if (result.data?.success === true) return { ok: true };
    return { ok: false, reason: 'ADAPTER_ERROR', detail: safeText };
  } catch (e) {
    console.error('recovery email adapter fetch failed', {
      name: e?.name || 'Error',
      message: String(e?.message || e || '').slice(0, 300),
    });
    return { ok: false, reason: 'FETCH_ERROR' };
  }
}

export async function studentChangePassword(ctx) {
  const a = await studentAuth(ctx); if (a.response) return a.response;
  const body = await parseJson(ctx.request);
  const currentPassword = String(body?.currentPassword || '');
  const newPassword = String(body?.newPassword || '');
  const confirmPassword = String(body?.confirmPassword || '');
  if (!currentPassword || !newPassword) return error('PASSWORD_CHANGE_FIELDS_REQUIRED', 'أدخل كلمة المرور الحالية والجديدة.', 400, ctx.requestId, ctx.cors);
  if (newPassword.length < 8 || newPassword.length > 256) return error('PASSWORD_TOO_SHORT', 'كلمة المرور يجب ألا تقل عن 8 أحرف.', 400, ctx.requestId, ctx.cors);
  if (newPassword !== confirmPassword) return error('PASSWORDS_MISMATCH', 'كلمتا المرور غير متطابقتين.', 400, ctx.requestId, ctx.cors);
  if (currentPassword === newPassword) return error('PASSWORD_UNCHANGED', 'كلمة المرور الجديدة يجب أن تختلف عن الحالية.', 400, ctx.requestId, ctx.cors);
  const student = await queryOne(ctx.env, 'SELECT * FROM students WHERE id=? AND active=1 LIMIT 1', a.session.student_id);
  if (!student || !(await verifySecret(currentPassword, student.auth_secret_hash, student.auth_secret_salt, student.auth_secret_algo))) {
    await recordAuthEvent(ctx, 'student', a.session.student_id, 'password_change_failed');
    return error('CURRENT_PASSWORD_INVALID', 'كلمة المرور الحالية غير صحيحة.', 401, ctx.requestId, ctx.cors);
  }
  const salt = token(16);
  const hash = await pbkdf2Hash(newPassword, salt);
  await ctx.env.DB.prepare(`UPDATE students SET auth_secret_hash=?, auth_secret_salt=?, auth_secret_algo='pbkdf2-sha256', failed_login_attempts=0, locked_until=NULL, updated_at=CURRENT_TIMESTAMP WHERE id=?`)
    .bind(hash, salt, a.session.student_id).run();
  await ctx.env.DB.prepare(`UPDATE sessions SET revoked_at=CURRENT_TIMESTAMP WHERE student_id=? AND revoked_at IS NULL`).bind(a.session.student_id).run();
  await recordAuthEvent(ctx, 'student', a.session.student_id, 'password_changed');
  return ok(ctx, { changed: true });
}

export async function forgotStudentPassword(ctx) {
  const ipLimit = await authIpRateLimit(ctx, 'student_password_reset', AUTH_IP_LOGIN_LIMIT);
  if (!ipLimit.allowed) return error('AUTH_RATE_LIMITED', 'تم تجاوز عدد المحاولات مؤقتًا. حاول لاحقًا.', 429, ctx.requestId, ctx.cors);
  const body = await parseJson(ctx.request);
  const studentNumber = String(body?.studentNumber || body?.identifier || '').trim();
  if (!studentNumber) return error('RECOVERY_IDENTIFIER_REQUIRED', 'أدخل الرقم الجامعي.', 400, ctx.requestId, ctx.cors);
  const student = await queryOne(ctx.env, 'SELECT id,email,active FROM students WHERE student_number=? LIMIT 1', studentNumber);
  if (!student || student.active !== 1) return error('RECOVERY_STUDENT_NOT_FOUND', 'تعذر العثور على الطالب.', 404, ctx.requestId, ctx.cors);
  if (!student.email) return error('NO_RECOVERY_EMAIL', 'لا يوجد بريد استعادة مضاف لهذا الحساب. يرجى التواصل مع المسؤولين لحل مشكلتك.', 400, ctx.requestId, ctx.cors);
  const recoveryEmail = normalizeEmail(student.email);
  if (!isValidEmail(recoveryEmail)) {
    console.error('Invalid stored recovery email', { studentId: student.id });
    return error('RECOVERY_EMAIL_INVALID', 'البريد الإلكتروني المسجل لهذا الحساب غير صالح. يرجى التواصل مع الإدارة لتحديثه.', 400, ctx.requestId, ctx.cors);
  }

  const random = new Uint32Array(1); crypto.getRandomValues(random); const code = String(100000 + (random[0] % 900000));
  const codeHash = await sha256(code);
  const id = crypto.randomUUID();
  await ctx.env.DB.prepare(`UPDATE password_reset_codes SET used_at=CURRENT_TIMESTAMP WHERE student_id=? AND used_at IS NULL`).bind(student.id).run();
  await ctx.env.DB.prepare(`INSERT INTO password_reset_codes (id,student_id,code_hash,expires_at,attempts,created_at) VALUES (?,?,?,datetime('now','+10 minutes'),0,CURRENT_TIMESTAMP)`)
    .bind(id, student.id, codeHash).run();
  const delivery = await sendStudentRecoveryEmail(ctx, recoveryEmail, code);
  if (!delivery.ok) {
    await ctx.env.DB.prepare('UPDATE password_reset_codes SET used_at=CURRENT_TIMESTAMP WHERE id=?').bind(id).run();
    if (delivery.reason === 'INVALID_EMAIL') {
      return error('RECOVERY_EMAIL_INVALID', 'البريد الإلكتروني المسجل لهذا الحساب غير صالح. يرجى التواصل مع الإدارة لتحديثه.', 400, ctx.requestId, ctx.cors);
    }
    return error('RECOVERY_EMAIL_UNAVAILABLE', 'تعذر إرسال رسالة الاستعادة حاليًا. حاول لاحقًا.', 503, ctx.requestId, ctx.cors);
  }
  await recordAuthEvent(ctx, 'student', student.id, 'password_reset_requested');
  return ok(ctx, { sent: true, expiresInSeconds: 600 });
}

export async function resetStudentPassword(ctx) {
  const ipLimit = await authIpRateLimit(ctx, 'student_password_reset_verify', AUTH_IP_LOGIN_LIMIT);
  if (!ipLimit.allowed) return error('AUTH_RATE_LIMITED', 'تم تجاوز عدد المحاولات مؤقتًا. حاول لاحقًا.', 429, ctx.requestId, ctx.cors);
  const body = await parseJson(ctx.request);
  const studentNumber = String(body?.studentNumber || '').trim();
  const code = String(body?.code || '').trim();
  const newPassword = String(body?.newPassword || '');
  const confirmPassword = String(body?.confirmPassword || '');
  if (!studentNumber || !/^\d{6}$/.test(code) || !newPassword) return error('RECOVERY_VERIFY_FIELDS_REQUIRED', 'أدخل الرقم الجامعي ورمز الاستعادة وكلمة المرور الجديدة.', 400, ctx.requestId, ctx.cors);
  if (newPassword.length < 8 || newPassword.length > 256) return error('PASSWORD_TOO_SHORT', 'كلمة المرور يجب ألا تقل عن 8 أحرف.', 400, ctx.requestId, ctx.cors);
  if (newPassword !== confirmPassword) return error('PASSWORDS_MISMATCH', 'كلمتا المرور غير متطابقتين.', 400, ctx.requestId, ctx.cors);
  const student = await queryOne(ctx.env, 'SELECT id FROM students WHERE student_number=? AND active=1 LIMIT 1', studentNumber);
  if (!student) return error('RECOVERY_INVALID', 'رمز الاستعادة أو بيانات الطالب غير صحيحة.', 400, ctx.requestId, ctx.cors);
  const row = await queryOne(ctx.env, `SELECT * FROM password_reset_codes WHERE student_id=? AND used_at IS NULL AND expires_at>CURRENT_TIMESTAMP ORDER BY created_at DESC LIMIT 1`, student.id);
  if (!row) return error('RECOVERY_CODE_EXPIRED', 'رمز الاستعادة منتهي أو غير صالح. اطلب رمزًا جديدًا.', 400, ctx.requestId, ctx.cors);
  if (Number(row.attempts || 0) >= 5) return error('RECOVERY_TOO_MANY_ATTEMPTS', 'تم تجاوز عدد محاولات الرمز. اطلب رمزًا جديدًا.', 429, ctx.requestId, ctx.cors);
  const valid = await timingSafeEqualHex(await sha256(code), row.code_hash);
  if (!valid) {
    await ctx.env.DB.prepare('UPDATE password_reset_codes SET attempts=attempts+1 WHERE id=?').bind(row.id).run();
    return error('RECOVERY_CODE_INVALID', 'رمز الاستعادة غير صحيح.', 400, ctx.requestId, ctx.cors);
  }
  const salt = token(16);
  const hash = await pbkdf2Hash(newPassword, salt);
  await ctx.env.DB.prepare(`UPDATE students SET auth_secret_hash=?, auth_secret_salt=?, auth_secret_algo='pbkdf2-sha256', failed_login_attempts=0, locked_until=NULL, updated_at=CURRENT_TIMESTAMP WHERE id=?`)
    .bind(hash, salt, student.id).run();
  await ctx.env.DB.prepare('UPDATE password_reset_codes SET used_at=CURRENT_TIMESTAMP WHERE id=?').bind(row.id).run();
  await ctx.env.DB.prepare('UPDATE sessions SET revoked_at=CURRENT_TIMESTAMP WHERE student_id=? AND revoked_at IS NULL').bind(student.id).run();
  await recordAuthEvent(ctx, 'student', student.id, 'password_reset_completed');
  return ok(ctx, { changed: true });
}

export async function staffLogin(ctx) {
  const ipLimit = await authIpRateLimit(ctx, 'staff_login', AUTH_IP_LOGIN_LIMIT);
  if (!ipLimit.allowed) return error('AUTH_RATE_LIMITED', 'تم تجاوز عدد محاولات تسجيل الدخول مؤقتًا. حاول لاحقًا.', 429, ctx.requestId, ctx.cors);
  const body = await parseJson(ctx.request);
  const userId = String(body?.userId || body?.username || body?.email || '').trim();
  const loginKey = userId.toLowerCase();
  const password = String(body?.password || '');
  if (!userId || !password || userId.length > 128 || password.length > 256) return error('AUTH_INPUT_INVALID', 'أدخل اسم المستخدم وكلمة المرور.', 400, ctx.requestId, ctx.cors);
  const staff = await queryOne(ctx.env, 'SELECT su.*, r.name AS role_name FROM staff_users su JOIN roles r ON r.id = su.role_id WHERE lower(su.user_id) = ? AND su.active = 1 LIMIT 1', loginKey);
  if (!staff || !staff.password_hash) return error('AUTH_INVALID_CREDENTIALS', 'بيانات تسجيل الدخول غير صحيحة.', 401, ctx.requestId, ctx.cors);
  if (staff.locked_until && new Date(staff.locked_until).getTime() > Date.now()) return lockedResponse(ctx);
  const valid = await verifySecret(password, staff.password_hash, staff.password_salt, staff.password_algo);
  if (!valid) {
    await ctx.env.DB.prepare(`
      UPDATE staff_users
      SET failed_login_attempts = failed_login_attempts + 1,
          locked_until = CASE
            WHEN failed_login_attempts + 1 >= ?
              THEN datetime('now', '+' || ? || ' seconds')
            ELSE locked_until
          END
      WHERE id = ? AND active = 1
    `).bind(AUTH_MAX_FAILED, AUTH_LOCK_SECONDS, staff.id).run();
    const state = await queryOne(ctx.env, 'SELECT failed_login_attempts, locked_until FROM staff_users WHERE id=?', staff.id);
    const locked = Number(state?.failed_login_attempts || 0) >= AUTH_MAX_FAILED && state?.locked_until;
    await recordAuthEvent(ctx, 'staff', staff.id, locked ? 'login_locked' : 'login_failed');
    return locked ? lockedResponse(ctx) : error('AUTH_INVALID_CREDENTIALS', 'بيانات تسجيل الدخول غير صحيحة.', 401, ctx.requestId, ctx.cors);
  }
  await ctx.env.DB.prepare('UPDATE staff_users SET failed_login_attempts = 0, locked_until = NULL, last_login_at = CURRENT_TIMESTAMP WHERE id = ?').bind(staff.id).run();
  await recordAuthEvent(ctx, 'staff', staff.id, 'login_success');
  return issueSession(ctx, { staffUserId: staff.id });
}

export async function staffBootstrap(ctx) {
  const supplied = String(ctx.request.headers.get('X-Staff-Bootstrap-Token') || '');
  const expected = String(ctx.env.STAFF_BOOTSTRAP_TOKEN || '');
  if (!expected || !supplied || !timingSafeEqualHex(await sha256(supplied), await sha256(expected))) return error('BOOTSTRAP_FORBIDDEN', 'رمز التهيئة غير صالح.', 403, ctx.requestId, ctx.cors);
  const count = await queryOne(ctx.env, 'SELECT COUNT(*) AS count FROM staff_users');
  if (Number(count?.count || 0) > 0) return error('BOOTSTRAP_ALREADY_DONE', 'تمت تهيئة حسابات الإدارة مسبقًا.', 409, ctx.requestId, ctx.cors);
  const body = await parseJson(ctx.request);
  const userId = String(body?.userId || body?.username || body?.email || '').trim();
  const emailRaw = String(body?.email || '').trim();
  const email = emailRaw ? emailRaw.toLowerCase() : null;
  const displayName = String(body?.displayName || '').trim();
  const password = String(body?.password || '');
  if (!userId || userId.length > 128 || !displayName || password.length < 8 || password.length > 256) return error('BOOTSTRAP_INPUT_INVALID', 'بيانات حساب الإدارة غير صالحة. اسم المستخدم مطلوب وكلمة المرور يجب ألا تقل عن 8 أحرف.', 400, ctx.requestId, ctx.cors);
  const role = await queryOne(ctx.env, "SELECT id FROM roles WHERE id = 'super_admin' LIMIT 1");
  if (!role) return error('BOOTSTRAP_ROLE_MISSING', 'دور المدير العام غير موجود. طبّق migrations أولًا.', 503, ctx.requestId, ctx.cors);
  const salt = token(16);
  const hash = await pbkdf2Hash(password, salt);
  const id = crypto.randomUUID();
  await ctx.env.DB.prepare('INSERT INTO staff_users (id, user_id, email, display_name, role_id, password_hash, password_salt, password_algo) VALUES (?, ?, ?, ?, ?, ?, ?, ?)')
    .bind(id, userId, email, displayName, role.id, hash, salt, 'pbkdf2-sha256').run();
  await recordAuthEvent(ctx, 'staff', id, 'bootstrap_created');
  return ok(ctx, { created: true, staffUserId: id, userId, email, role: 'super_admin' }, null, 201);
}

export async function staffMe(ctx) {
  const a = await staffAuth(ctx); if (a.response) return a.response;
  return ok(ctx, {
    id: a.session.staff_user_id,
    user_id: a.session.staff_user_id_login,
    email: a.session.staff_email,
    display_name: a.session.staff_display_name,
    role_id: a.session.staff_role_id,
    role_name: a.session.staff_role_name,
  });
}

export async function staffChangePassword(ctx) {
  const a = await staffAuth(ctx);
  if (a.response) return a.response;

  const body = await parseJson(ctx.request);
  const currentPassword = String(body?.currentPassword || '');
  const newPassword = String(body?.newPassword || '');
  if (!currentPassword || !newPassword || newPassword.length < 8 || newPassword.length > 256) {
    return error('STAFF_PASSWORD_INVALID', 'كلمة المرور الجديدة يجب أن تكون بين 8 و256 حرفًا.', 400, ctx.requestId, ctx.cors);
  }
  if (currentPassword === newPassword) {
    return error('STAFF_PASSWORD_UNCHANGED', 'كلمة المرور الجديدة يجب أن تختلف عن الحالية.', 400, ctx.requestId, ctx.cors);
  }

  const staff = await queryOne(ctx.env, 'SELECT id, user_id, email, password_hash, password_salt, password_algo, failed_login_attempts, locked_until, active FROM staff_users WHERE id = ? LIMIT 1', a.session.staff_user_id);
  if (!staff || staff.active !== 1) {
    return error('STAFF_NOT_FOUND', 'حساب الإدارة غير موجود أو غير فعال.', 403, ctx.requestId, ctx.cors);
  }
  if (staff.locked_until && new Date(staff.locked_until).getTime() > Date.now()) return lockedResponse(ctx);

  const valid = await verifySecret(currentPassword, staff.password_hash, staff.password_salt, staff.password_algo);
  if (!valid) {
    const failed = (staff.failed_login_attempts || 0) + 1;
    const locked = failed >= AUTH_MAX_FAILED ? new Date(Date.now() + AUTH_LOCK_SECONDS * 1000).toISOString() : null;
    await ctx.env.DB.prepare('UPDATE staff_users SET failed_login_attempts = ?, locked_until = ? WHERE id = ?').bind(failed, locked, staff.id).run();
    await recordAuthEvent(ctx, 'staff', staff.id, locked ? 'password_change_locked' : 'password_change_failed');
    return locked ? lockedResponse(ctx) : error('STAFF_PASSWORD_CURRENT_INVALID', 'كلمة المرور الحالية غير صحيحة.', 401, ctx.requestId, ctx.cors);
  }

  const salt = token(16);
  const hash = await pbkdf2Hash(newPassword, salt);
  await ctx.env.DB.prepare('UPDATE staff_users SET password_hash = ?, password_salt = ?, password_algo = \'pbkdf2-sha256\', failed_login_attempts = 0, locked_until = NULL, updated_at = CURRENT_TIMESTAMP WHERE id = ?')
    .bind(hash, salt, staff.id).run();

  // Revoke every other active session. The current session remains usable so the admin
  // can continue working without an unexpected logout after a successful change.
  await ctx.env.DB.prepare('UPDATE sessions SET revoked_at = CURRENT_TIMESTAMP WHERE staff_user_id = ? AND id <> ? AND revoked_at IS NULL')
    .bind(staff.id, a.session.id).run();

  await recordAuthEvent(ctx, 'staff', staff.id, 'password_changed');
  await writeAudit(ctx, staff.id, 'change_password', 'staff_users', staff.id);
  return ok(ctx, { changed: true, otherSessionsRevoked: true });
}

export async function refresh(ctx) {
  const ipLimit = await authIpRateLimit(ctx, 'refresh', AUTH_IP_REFRESH_LIMIT);
  if (!ipLimit.allowed) return error('AUTH_RATE_LIMITED', 'تم تجاوز عدد محاولات تحديث الجلسة مؤقتًا. حاول لاحقًا.', 429, ctx.requestId, ctx.cors);
  const body = await parseJson(ctx.request); const raw = String(body?.refreshToken || '');
  if (!raw || raw.length > 4096) return error('AUTH_REFRESH_REQUIRED', 'رمز التحديث مطلوب.', 400, ctx.requestId, ctx.cors);
  const hash = await sha256(raw);
  const session = await queryOne(ctx.env, 'SELECT * FROM sessions WHERE refresh_token_hash = ? AND revoked_at IS NULL AND refresh_expires_at > CURRENT_TIMESTAMP LIMIT 1', hash);
  if (!session) {
    await recordAuthEvent(ctx, 'unknown', null, 'refresh_reuse_or_invalid');
    return error('AUTH_REFRESH_INVALID', 'رمز التحديث غير صالح أو منتهي.', 401, ctx.requestId, ctx.cors);
  }

  // Claim the refresh token atomically. This closes the rotation race where two
  // concurrent requests could both exchange the same refresh token.
  const claim = await ctx.env.DB.prepare(
    'UPDATE sessions SET revoked_at = CURRENT_TIMESTAMP WHERE id = ? AND refresh_token_hash = ? AND revoked_at IS NULL AND refresh_expires_at > CURRENT_TIMESTAMP'
  ).bind(session.id, hash).run();
  if (!claim.meta?.changes) {
    await recordAuthEvent(ctx, session.staff_user_id ? 'staff' : 'student', session.staff_user_id || session.student_id, 'refresh_reuse_detected');
    return error('AUTH_REFRESH_REUSED', 'تم استخدام رمز التحديث من قبل. سجّل الدخول مجددًا.', 401, ctx.requestId, ctx.cors);
  }

  // Do not mint a new session for an account that has since been disabled.
  if (session.staff_user_id) {
    const staff = await queryOne(ctx.env, 'SELECT active FROM staff_users WHERE id=? LIMIT 1', session.staff_user_id);
    if (!staff?.active) return error('AUTH_ACCOUNT_DISABLED', 'حساب الإدارة معطل.', 403, ctx.requestId, ctx.cors);
  }
  if (session.student_id) {
    const student = await queryOne(ctx.env, 'SELECT active FROM students WHERE id=? LIMIT 1', session.student_id);
    if (!student?.active) return error('AUTH_ACCOUNT_DISABLED', 'حساب الطالب معطل.', 403, ctx.requestId, ctx.cors);
  }
  await recordAuthEvent(ctx, session.staff_user_id ? 'staff' : 'student', session.staff_user_id || session.student_id, 'refresh_success');
  return issueSession(ctx, { studentId: session.student_id, staffUserId: session.staff_user_id });
}

export async function logout(ctx) {
  const raw = bearer(ctx.request); if (!raw) return ok(ctx, { loggedOut: true });
  await ctx.env.DB.prepare('UPDATE sessions SET revoked_at = CURRENT_TIMESTAMP WHERE access_token_hash = ?').bind(await sha256(raw)).run();
  return ok(ctx, { loggedOut: true });
}

export async function issueSession(ctx, identity) {
  const hasStudent = Boolean(identity?.studentId);
  const hasStaff = Boolean(identity?.staffUserId);
  if (hasStudent === hasStaff) throw new Error('SESSION_IDENTITY_INVALID');
  const accessToken = token(32), refreshToken = token(48);
  const now = Date.now();
  const expiresAt = new Date(now + AUTH_ACCESS_TTL * 1000).toISOString();
  const refreshExpiresAt = new Date(now + AUTH_REFRESH_TTL * 1000).toISOString();
  const id = crypto.randomUUID();
  await ctx.env.DB.prepare('INSERT INTO sessions (id,student_id,staff_user_id,access_token_hash,refresh_token_hash,expires_at,refresh_expires_at) VALUES (?,?,?,?,?,?,?)')
    .bind(id, identity.studentId || null, identity.staffUserId || null, await sha256(accessToken), await sha256(refreshToken), expiresAt, refreshExpiresAt).run();
  let profile = {};
  if (identity.staffUserId) profile = await queryOne(ctx.env, 'SELECT su.id AS staffUserId,su.user_id AS staffUserIdLogin,su.email AS staffEmail,su.display_name AS staffDisplayName,su.role_id AS staffRoleId,r.name AS staffRole FROM staff_users su JOIN roles r ON r.id=su.role_id WHERE su.id=?', identity.staffUserId) || {};
  if (identity.studentId) profile = await queryOne(ctx.env, `
    SELECT st.id AS studentId, st.student_number AS studentNumber, st.full_name AS fullName,
           st.email, st.department_id AS departmentId, d.name_ar AS departmentName,
           st.current_semester_id AS currentSemesterId, se.name_ar AS semesterName
    FROM students st
    LEFT JOIN departments d ON d.id = st.department_id
    LEFT JOIN semesters se ON se.id = st.current_semester_id
    WHERE st.id = ?
  `, identity.studentId) || {};
  return ok(ctx, { token: accessToken, refreshToken, expiresInSeconds: AUTH_ACCESS_TTL, refreshExpiresInSeconds: AUTH_REFRESH_TTL, ...profile });
}

export async function authMe(ctx) {
  const base = await auth(ctx); if (base.response) return base.response;
  const a = base.session.student_id ? await studentAuth(ctx) : await staffAuth(ctx);
  if (a.response) return a.response;
  return ok(ctx, sanitizeSession(a.session));
}

export function sanitizeSession(row) {
  return {
    studentId: row.student_id || null,
    studentNumber: row.student_number || null,
    fullName: row.full_name || null,
    departmentId: row.department_id || null,
    staffUserId: row.staff_user_id || null,
    staffUserIdLogin: row.staff_user_id_login || null,
    staffEmail: row.staff_email || null,
    staffDisplayName: row.staff_display_name || null,
    staffRoleId: row.staff_role_id || null,
    staffRole: row.staff_role_name || null,
    expiresAt: row.expires_at,
  };
}
