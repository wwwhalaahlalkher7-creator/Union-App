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
  var effectiveEmail = String(Session.getEffectiveUser().getEmail() || '').trim().toLowerCase();

  // This service must always execute under the dedicated TRINEX support account.
  // It is the sender, never the recovery recipient.
  if (effectiveEmail !== 'trinex.support@gmail.com') {
    throw new Error('GMAIL_SENDER_ACCOUNT_MISMATCH');
  }

  if (!isValidEmailAddress(recipient)) throw new Error('INVALID_EMAIL');
  if (!/^\d{6}$/.test(recoveryCode)) throw new Error('INVALID_RECOVERY_CODE');
  if (recipient === effectiveEmail) throw new Error('RECOVERY_RECIPIENT_IS_SENDER');

  var subject = 'رمز استعادة كلمة مرور TRINEX';
  var body =
    'رمز استعادة كلمة مرور حسابك في TRINEX هو: ' + recoveryCode +
    '\n\nالرمز صالح لمدة 10 دقائق.\n\nإذا لم تطلب استعادة كلمة المرور، فتجاهل هذه الرسالة ولا تشارك الرمز مع أي شخص.';

  var htmlBody = buildRecoveryEmailHtml(recoveryCode);

  MailApp.sendEmail({
    to: recipient,
    subject: subject,
    body: body,
    htmlBody: htmlBody,
    name: 'TRINEX Support'
  });

  Logger.log(JSON.stringify({
    success: true,
    service: 'TRINEX Gmail',
    recipientDomain: recipient.split('@')[1]
  }));

  return { success: true };
}


function buildRecoveryEmailHtml(code) {
  // Email clients do not reliably allow JavaScript clipboard actions. The code
  // is therefore rendered as a large, selectable OTP block so Gmail and other
  // clients can recognize/select it easily without relying on scripts.
  return '<!doctype html>' +
    '<html lang="ar" dir="rtl"><head><meta charset="UTF-8"></head>' +
    '<body style="margin:0;padding:0;background:#f4f7fb;font-family:Arial,Helvetica,sans-serif;color:#182230;">' +
      '<div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">رمز استعادة كلمة المرور في TRINEX: ' + code + '</div>' +
      '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4f7fb;padding:28px 12px;">' +
        '<tr><td align="center">' +
          '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border:1px solid #e4e9f0;border-radius:20px;overflow:hidden;">' +
            '<tr><td style="padding:26px 28px 18px;text-align:center;background:#101722;">' +
              '<div style="font-size:26px;font-weight:800;letter-spacing:1px;color:#ffffff;">TRINEX</div>' +
              '<div style="margin-top:6px;font-size:13px;color:#b9c5d4;">منصة كلية الهندسة والعمارة</div>' +
            '</td></tr>' +
            '<tr><td style="padding:30px 28px;text-align:right;">' +
              '<h1 style="margin:0 0 10px;font-size:22px;line-height:1.5;color:#182230;">استعادة كلمة المرور</h1>' +
              '<p style="margin:0 0 22px;font-size:15px;line-height:1.9;color:#566274;">تلقينا طلبًا لإعادة تعيين كلمة مرور حسابك في TRINEX. استخدم رمز التحقق التالي لإكمال العملية:</p>' +
              '<div style="margin:0 auto 22px;padding:20px 16px;text-align:center;border:1px solid #dfe6ef;border-radius:16px;background:#f7f9fc;">' +
                '<div style="font-size:12px;font-weight:700;color:#687589;margin-bottom:10px;">رمز الاستعادة</div>' +
                '<div style="font-family:monospace,Arial,sans-serif;font-size:34px;font-weight:900;line-height:1.25;letter-spacing:9px;color:#101722;direction:ltr;unicode-bidi:plaintext;user-select:all;">' + code + '</div>' +
                '<div style="margin-top:10px;font-size:12px;color:#7a8798;">يمكنك تحديد الرمز ونسخه بسهولة.</div>' +
              '</div>' +
              '<div style="padding:14px 16px;border-radius:12px;background:#fff8e8;border:1px solid #f0dfb3;color:#6f5a25;font-size:13px;line-height:1.8;">هذا الرمز صالح لمدة <strong>10 دقائق</strong> فقط، ولا تشاركه مع أي شخص.</div>' +
              '<p style="margin:22px 0 0;font-size:13px;line-height:1.8;color:#6c7888;">إذا لم تطلب استعادة كلمة المرور، يمكنك تجاهل هذه الرسالة بأمان.</p>' +
            '</td></tr>' +
            '<tr><td style="padding:18px 28px;border-top:1px solid #edf0f4;text-align:center;color:#8994a3;font-size:11px;line-height:1.7;">رسالة آلية من TRINEX Support<br>لا ترد على هذه الرسالة.</td></tr>' +
          '</table>' +
        '</td></tr>' +
      '</table>' +
    '</body></html>';
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
  // Intentionally does not send an email. Production delivery must be tested
  // through the Worker so the real student's stored email is used.
  var effectiveEmail = String(Session.getEffectiveUser().getEmail() || '').trim().toLowerCase();
  if (effectiveEmail !== 'trinex.support@gmail.com') {
    throw new Error('GMAIL_SENDER_ACCOUNT_MISMATCH');
  }
  var result = {
    success: true,
    service: 'TRINEX Gmail',
    sender: effectiveEmail,
    note: 'No email was sent. Use the application recovery flow for a real recipient test.'
  };
  Logger.log(JSON.stringify(result));
  return result;
}
