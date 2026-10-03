/**
 * TRINEX Gmail — Google Apps Script
 *
 * هذا المشروع مستقل تمامًا عن TRINEX Drive.
 * وظيفته الحالية: إرسال رموز استعادة كلمة المرور.
 * يمكن إضافة خدمات بريد أخرى مستقبلًا دون لمس مشروع Drive.
 *
 * Script Properties:
 *   EMAIL_API_TOKEN = سر طويل عشوائي يطابق Worker secret
 *
 * النشر:
 *   Deploy → New deployment → Web app
 *   Execute as: Me (حساب trinex.support@gmail.com)
 *   Who has access: Anyone
 */

var EMAIL_API_TOKEN_KEY = 'EMAIL_API_TOKEN';

function doGet() {
  return HtmlService.createHtmlOutput(
    '<!doctype html><html lang="ar"><head><meta charset="utf-8"><title>TRINEX Gmail</title>' +
    '<style>body{font-family:Arial,sans-serif;padding:32px;line-height:1.7}h1{margin-bottom:8px}</style>' +
    '</head><body><h1>TRINEX Gmail</h1><p>خدمة البريد تعمل.</p><p>هذا المشروع مخصص لعمليات البريد فقط.</p></body></html>'
  );
}

function doPost(e) {
  var result;
  try {
    var body = parseJsonBody(e);
    if (body.action !== 'sendRecoveryEmail') {
      throw new Error('UNKNOWN_ACTION');
    }

    requireEmailToken(String(body.token || ''));
    result = sendRecoveryEmail(body.to, body.code);
    Logger.log('TRINEX Gmail: recovery email sent successfully.');
  } catch (err) {
    var message = String(err && err.message ? err.message : err);
    result = { success: false, error: message };
    Logger.log('TRINEX Gmail request failed: ' + message);
  }

  return ContentService.createTextOutput(JSON.stringify(result))
    .setMimeType(ContentService.MimeType.JSON);
}

function parseJsonBody(e) {
  var contents = String(e && e.postData && e.postData.contents || '').trim();
  if (!contents) throw new Error('INVALID_REQUEST');
  try {
    return JSON.parse(contents);
  } catch (err) {
    throw new Error('INVALID_REQUEST');
  }
}

function requireEmailToken(token) {
  var expected = String(
    PropertiesService.getScriptProperties().getProperty(EMAIL_API_TOKEN_KEY) || ''
  ).trim();
  if (!expected) throw new Error('EMAIL_API_TOKEN_NOT_CONFIGURED');
  if (!token || token !== expected) throw new Error('UNAUTHORIZED');
}

function normalizeEmailAddress(value) {
  return String(value || '')
    .normalize('NFKC')
    .replace(/[\u0000-\u001F\u007F\u200B-\u200D\u2060\uFEFF]/g, '')
    .trim()
    .toLowerCase();
}

function isValidEmailAddress(value) {
  var email = normalizeEmailAddress(value);
  if (!email || email.length > 254) return false;

  var at = email.lastIndexOf('@');
  if (at <= 0 || at !== email.indexOf('@') || at === email.length - 1) return false;

  var local = email.slice(0, at);
  var domain = email.slice(at + 1);

  if (
    local.length > 64 ||
    local.indexOf('..') !== -1 ||
    local.charAt(0) === '.' ||
    local.charAt(local.length - 1) === '.'
  ) return false;

  if (!/^[A-Za-z0-9.!#$%&'*+\/?^_`{|}~-]+$/.test(local)) return false;
  if (domain.length > 253 || domain.indexOf('.') === -1) return false;

  var labels = domain.split('.');
  for (var i = 0; i < labels.length; i++) {
    if (
      !labels[i] ||
      labels[i].length > 63 ||
      labels[i].charAt(0) === '-' ||
      labels[i].charAt(labels[i].length - 1) === '-' ||
      !/^[A-Za-z0-9-]+$/.test(labels[i])
    ) return false;
  }

  return true;
}

function sendRecoveryEmail(to, code) {
  var recipient = normalizeEmailAddress(to);
  var recoveryCode = String(code || '').trim();

  if (!isValidEmailAddress(recipient)) throw new Error('INVALID_EMAIL');
  if (!/^\d{6}$/.test(recoveryCode)) throw new Error('INVALID_RECOVERY_CODE');

  var subject = 'رمز استعادة كلمة مرور TRINEX';
  var body =
    'رمز استعادة كلمة مرور حسابك في TRINEX هو: ' + recoveryCode +
    '\n\nالرمز صالح لمدة 10 دقائق. إذا لم تطلب استعادة كلمة المرور فتجاهل هذه الرسالة.';

  MailApp.sendEmail({
    to: recipient,
    subject: subject,
    body: body,
    name: 'TRINEX Support'
  });

  return { success: true };
}

function testMailAppSetup() {
  var effectiveEmail = String(Session.getEffectiveUser().getEmail() || '').trim();
  var quota = MailApp.getRemainingDailyQuota();

  if (!effectiveEmail) throw new Error('EFFECTIVE_USER_EMAIL_UNAVAILABLE');

  var result = {
    success: true,
    service: 'TRINEX Gmail',
    sender: effectiveEmail,
    remainingDailyQuota: quota
  };

  Logger.log(JSON.stringify(result));
  return result;
}

function testRecoveryEmail() {
  var effectiveEmail = String(Session.getEffectiveUser().getEmail() || '').trim();
  if (!isValidEmailAddress(effectiveEmail)) {
    throw new Error('EFFECTIVE_USER_EMAIL_INVALID');
  }

  var result = sendRecoveryEmail(effectiveEmail, '123456');
  Logger.log(JSON.stringify({ success: true, service: 'TRINEX Gmail', sentTo: effectiveEmail }));
  return result;
}
