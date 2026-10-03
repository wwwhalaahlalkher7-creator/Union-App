/**
 * TRINEX Drive — Google Apps Script
 *
 * هذا المشروع مستقل تمامًا عن TRINEX Gmail.
 * وظيفته: فهرسة المواد الدراسية من Google Drive، تسجيل فتح الملفات،
 * وحذف ملفات المواد عند طلب لوحة الإدارة.
 * لا يحتوي أي كود أو صلاحيات خاصة بالبريد.
 *
 * Script Properties:
 *   ROOT_FOLDER_ID = معرّف مجلد المواد الدراسية
 *   API_TOKEN      = سر طويل عشوائي يطابق Worker secret
 *   STATS_SHEET_ID = اختياري؛ ينشأ تلقائيًا عند الحاجة
 *
 * النشر:
 *   Deploy → New deployment → Web app
 *   Execute as: Me
 *   Who has access: Anyone
 */

var CACHE_KEY = 'trINEX_drive_index_v3';
var CACHE_TTL_SECONDS = 900;
var ROOT_FOLDER_KEY = 'ROOT_FOLDER_ID';
var API_TOKEN_KEY = 'API_TOKEN';
var STATS_SHEET_ID_KEY = 'STATS_SHEET_ID';
var MAX_DEPTH = 8;
var MAX_FILES = 10000;

function doGet(e) {
  var params = (e && e.parameter) || {};
  var action = params.action || 'index';

  // Safe browser check that does not require the Drive token.
  if (action === 'health') {
    return HtmlService.createHtmlOutput(
      '<!doctype html><html lang="ar"><head><meta charset="utf-8"><title>TRINEX Drive</title>' +
      '<style>body{font-family:Arial,sans-serif;padding:32px;line-height:1.7}h1{margin-bottom:8px}</style>' +
      '</head><body><h1>TRINEX Drive</h1><p>خدمة المواد الدراسية تعمل.</p><p>هذا المشروع مخصص لـ Google Drive فقط.</p></body></html>'
    );
  }

  var result;
  try {
    requireToken(params.token || '');

    if (action === 'index') {
      result = getIndex(params.nocache === '1');
    } else if (action === 'logOpen') {
      result = logFileOpen(params.fileId, params.fileName || '');
    } else {
      result = { success: false, error: 'UNKNOWN_ACTION' };
    }
  } catch (err) {
    result = { success: false, error: String(err && err.message ? err.message : err) };
  }

  return jsonResponse(result);
}

function doPost(e) {
  var result;

  try {
    var body = parseJsonBody(e);
    requireToken(String(body.token || ''));

    if (body.action === 'deleteFiles') {
      result = deleteFiles(body.fileIds || []);
    } else {
      result = { success: false, error: 'UNKNOWN_ACTION' };
    }
  } catch (err) {
    result = {
      success: false,
      error: String(err && err.message ? err.message : err)
    };
  }

  return jsonResponse(result);
}

function jsonResponse(value) {
  return ContentService.createTextOutput(JSON.stringify(value))
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

function requireToken(token) {
  var expected = String(
    PropertiesService.getScriptProperties().getProperty(API_TOKEN_KEY) || ''
  ).trim();

  if (!expected) throw new Error('API_TOKEN_NOT_CONFIGURED');
  if (!token || token !== expected) throw new Error('UNAUTHORIZED');
}

function getRootFolder() {
  var rootId = String(
    PropertiesService.getScriptProperties().getProperty(ROOT_FOLDER_KEY) || ''
  ).trim();

  if (!rootId) throw new Error('ROOT_FOLDER_ID_NOT_CONFIGURED');
  return DriveApp.getFolderById(rootId);
}

function deleteFiles(fileIds) {
  if (!Array.isArray(fileIds)) throw new Error('fileIds يجب أن تكون قائمة.');

  var uniqueIds = [];
  var seen = {};

  fileIds.forEach(function(id) {
    var value = String(id || '').trim();
    if (value && !seen[value]) {
      seen[value] = true;
      uniqueIds.push(value);
    }
  });

  if (!uniqueIds.length) {
    return { success: true, deleted: [], count: 0, failedCount: 0 };
  }

  if (uniqueIds.length > 100) {
    throw new Error('لا يمكن حذف أكثر من 100 ملف في الطلب الواحد.');
  }

  var deleted = [];
  var failed = [];

  uniqueIds.forEach(function(fileId) {
    try {
      // Verify that the Apps Script account can access the file first.
      DriveApp.getFileById(fileId).getName();

      var response = UrlFetchApp.fetch(
        'https://www.googleapis.com/drive/v3/files/' + encodeURIComponent(fileId) + '?supportsAllDrives=true',
        {
          method: 'delete',
          muteHttpExceptions: true,
          headers: {
            Authorization: 'Bearer ' + ScriptApp.getOAuthToken()
          }
        }
      );

      var status = response.getResponseCode();
      if (status !== 200 && status !== 204) {
        throw new Error(
          'Drive API HTTP ' + status + ': ' + response.getContentText()
        );
      }

      deleted.push(fileId);
    } catch (err) {
      failed.push({
        id: fileId,
        error: String(err && err.message ? err.message : err)
      });
    }
  });

  if (failed.length) {
    return {
      success: false,
      deleted: deleted,
      failed: failed,
      count: deleted.length,
      failedCount: failed.length
    };
  }

  CacheService.getScriptCache().remove(CACHE_KEY);

  return {
    success: true,
    deleted: deleted,
    count: deleted.length,
    failedCount: 0
  };
}

function getIndex(forceRefresh) {
  var cache = CacheService.getScriptCache();

  if (!forceRefresh) {
    var cached = cache.get(CACHE_KEY);
    if (cached) {
      try {
        return JSON.parse(cached);
      } catch (e) {}
    }
  }

  var data = buildIndex();

  try {
    var serialized = JSON.stringify(data);
    if (serialized.length < 95000) {
      cache.put(CACHE_KEY, serialized, CACHE_TTL_SECONDS);
    }
  } catch (e) {}

  return data;
}

function buildIndex() {
  var root = getRootFolder();
  var sections = [];
  var files = [];
  var sectionIterator = root.getFolders();

  while (sectionIterator.hasNext()) {
    var sectionFolder = sectionIterator.next();
    var section = {
      id: sectionFolder.getId(),
      name: sectionFolder.getName(),
      semesters: []
    };

    var semesterIterator = sectionFolder.getFolders();
    while (semesterIterator.hasNext()) {
      var semesterFolder = semesterIterator.next();
      var semesterFiles = [];

      collectPdfFiles(
        semesterFolder,
        semesterFolder.getId(),
        semesterFolder.getName(),
        null,
        0,
        semesterFiles,
        files,
        sectionFolder
      );

      section.semesters.push({
        id: semesterFolder.getId(),
        name: semesterFolder.getName(),
        fileCount: semesterFiles.length
      });
    }

    section.semesters.sort(function(a, b) {
      return naturalNameCompare(a.name, b.name);
    });

    sections.push(section);
  }

  sections.sort(function(a, b) {
    return String(a.name).localeCompare(String(b.name), 'ar');
  });

  files.sort(function(a, b) {
    return new Date(b.modified).getTime() - new Date(a.modified).getTime();
  });

  return {
    success: true,
    generatedAt: new Date().toISOString(),
    sections: sections,
    files: files,
    meta: {
      source: 'trinex-drive-apps-script',
      fileCount: files.length
    }
  };
}

function collectPdfFiles(folder, semesterId, semesterName, materialName, depth, semesterFiles, allFiles, sectionFolder) {
  if (depth > MAX_DEPTH) return;
  if (allFiles.length >= MAX_FILES) {
    throw new Error('تجاوز عدد الملفات الحد الآمن: ' + MAX_FILES);
  }

  var fileIterator = folder.getFilesByType(MimeType.PDF);
  while (fileIterator.hasNext()) {
    if (allFiles.length >= MAX_FILES) {
      throw new Error('تجاوز عدد الملفات الحد الآمن: ' + MAX_FILES);
    }

    var file = fileIterator.next();
    var currentMaterialName = materialName || null;

    semesterFiles.push(file.getId());

    allFiles.push({
      id: file.getId(),
      name: file.getName(),
      size: safeFileSize(file),
      modified: file.getLastUpdated().toISOString(),
      sectionId: sectionFolder.getId(),
      sectionName: sectionFolder.getName(),
      semesterId: semesterId,
      semesterName: semesterName,
      materialName: currentMaterialName,
      description: file.getDescription() || '',
      pinned: isPinnedDescription(file.getDescription()),
      openCount: 0,
      link: file.getUrl(),
      previewLink: 'https://drive.google.com/file/d/' + encodeURIComponent(file.getId()) + '/preview',
      downloadLink: 'https://drive.google.com/uc?export=download&id=' + encodeURIComponent(file.getId())
    });
  }

  var childIterator = folder.getFolders();
  while (childIterator.hasNext()) {
    var child = childIterator.next();
    var childMaterialName = materialName;

    if (folder.getId() === semesterId) {
      childMaterialName = child.getName();
    }

    collectPdfFiles(
      child,
      semesterId,
      semesterName,
      childMaterialName,
      depth + 1,
      semesterFiles,
      allFiles,
      sectionFolder
    );
  }
}

function safeFileSize(file) {
  try {
    return Number(file.getSize() || 0);
  } catch (e) {
    return 0;
  }
}

function isPinnedDescription(description) {
  var desc = String(description || '').toLowerCase();
  return ['pinned', 'مثبت', 'مثبّت'].some(function(k) {
    return desc.indexOf(k.toLowerCase()) !== -1;
  });
}

function naturalNameCompare(a, b) {
  var na = extractNumber(a);
  var nb = extractNumber(b);

  if (na !== null && nb !== null && na !== nb) return na - nb;
  return String(a).localeCompare(String(b), 'ar');
}

function extractNumber(value) {
  var match = String(value || '').match(/(\d+)/);
  return match ? parseInt(match[1], 10) : null;
}

function logFileOpen(fileId, fileName) {
  if (!fileId) return { success: false, error: 'fileId مفقود' };

  var lock = LockService.getScriptLock();
  lock.waitLock(10000);

  try {
    var sheet = getOrCreateStatsSheet();
    var data = sheet.getDataRange().getValues();
    var rowIndex = -1;

    for (var i = 1; i < data.length; i++) {
      if (data[i][0] === fileId) {
        rowIndex = i;
        break;
      }
    }

    var now = new Date();

    if (rowIndex === -1) {
      sheet.appendRow([fileId, fileName || '', 1, now]);
    } else {
      sheet.getRange(rowIndex + 1, 3).setValue((Number(data[rowIndex][2]) || 0) + 1);
      sheet.getRange(rowIndex + 1, 4).setValue(now);
      if (fileName) sheet.getRange(rowIndex + 1, 2).setValue(fileName);
    }

    return { success: true };
  } finally {
    lock.releaseLock();
  }
}

function getOrCreateStatsSheet() {
  var props = PropertiesService.getScriptProperties();
  var sheetId = props.getProperty(STATS_SHEET_ID_KEY);

  if (sheetId) {
    try {
      var existing = SpreadsheetApp.openById(sheetId).getSheetByName('الإحصائيات');
      if (existing) return existing;
    } catch (e) {}
  }

  var spreadsheet = SpreadsheetApp.create('إحصائيات المواد الدراسية - TRINEX');
  var sheet = spreadsheet.getSheets()[0];
  sheet.setName('الإحصائيات');
  sheet.appendRow(['معرف الملف', 'اسم الملف', 'عدد مرات الفتح', 'آخر فتح']);
  sheet.getRange('A1:D1').setFontWeight('bold');
  sheet.setFrozenRows(1);

  try {
    getRootFolder().addFile(DriveApp.getFileById(spreadsheet.getId()));
  } catch (e) {}

  props.setProperty(STATS_SHEET_ID_KEY, spreadsheet.getId());
  return sheet;
}

function testSetup() {
  var root = getRootFolder();
  var result = {
    success: true,
    service: 'TRINEX Drive',
    root: root.getName(),
    rootId: root.getId()
  };

  Logger.log(JSON.stringify(result));
  return result;
}
