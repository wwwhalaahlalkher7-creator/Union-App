/**
 * TRINEX — Google Drive Adapter (Google Apps Script)
 *
 * وظيفته الوحيدة: قراءة أرشيف المواد من Google Drive وإرجاع JSON موحد
 * للـ Cloudflare Worker. لا توجد مفاتيح Service Account هنا.
 *
 * الإعداد مرة واحدة عبر Project Settings → Script properties:
 *   ROOT_FOLDER_ID = معرّف مجلد "المواد الدراسية"
 *   API_TOKEN      = سر طويل عشوائي، يجب أن يطابق سر Worker
 *
 * النشر: Deploy → New deployment → Web app → Execute as Me → Anyone.
 */

var CACHE_KEY = 'trINEX_drive_index_v2';
var CACHE_TTL_SECONDS = 900;
var ROOT_FOLDER_KEY = 'ROOT_FOLDER_ID';
var API_TOKEN_KEY = 'API_TOKEN';
var STATS_SHEET_ID_KEY = 'STATS_SHEET_ID';
var MAX_DEPTH = 8;
var MAX_FILES = 10000;

function doGet(e) {
  var params = (e && e.parameter) || {};
  var action = params.action || 'index';
  var result;

  try {
    requireToken(params.token || '');
    if (action === 'index') {
      result = getIndex(params.nocache === '1');
    } else if (action === 'logOpen') {
      result = logFileOpen(params.fileId, params.fileName || '');
    } else {
      result = { success: false, error: 'إجراء غير معروف.' };
    }
  } catch (err) {
    result = { success: false, error: String(err && err.message ? err.message : err) };
  }

  return ContentService.createTextOutput(JSON.stringify(result))
    .setMimeType(ContentService.MimeType.JSON);
}

function requireToken(token) {
  var expected = String(PropertiesService.getScriptProperties().getProperty(API_TOKEN_KEY) || '').trim();
  if (!expected) throw new Error('API_TOKEN غير مهيأ في Script properties.');
  if (!token || token !== expected) throw new Error('غير مصرح.');
}

function getRootFolder() {
  var rootId = String(PropertiesService.getScriptProperties().getProperty(ROOT_FOLDER_KEY) || '').trim();
  if (!rootId) throw new Error('ROOT_FOLDER_ID غير مهيأ في Script properties.');
  return DriveApp.getFolderById(rootId);
}

function getIndex(forceRefresh) {
  var cache = CacheService.getScriptCache();
  if (!forceRefresh) {
    var cached = cache.get(CACHE_KEY);
    if (cached) {
      try { return JSON.parse(cached); } catch (e) {}
    }
  }

  var data = buildIndex();
  try {
    var serialized = JSON.stringify(data);
    if (serialized.length < 95000) cache.put(CACHE_KEY, serialized, CACHE_TTL_SECONDS);
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
      collectPdfFiles(semesterFolder, semesterFolder.getId(), semesterFolder.getName(), null, 0, semesterFiles, files, sectionFolder);
      section.semesters.push({
        id: semesterFolder.getId(),
        name: semesterFolder.getName(),
        fileCount: semesterFiles.length
      });
    }

    section.semesters.sort(function(a, b) { return naturalNameCompare(a.name, b.name); });
    sections.push(section);
  }

  sections.sort(function(a, b) { return String(a.name).localeCompare(String(b.name), 'ar'); });
  files.sort(function(a, b) {
    return new Date(b.modified).getTime() - new Date(a.modified).getTime();
  });

  return {
    success: true,
    generatedAt: new Date().toISOString(),
    sections: sections,
    files: files,
    meta: { source: 'google-drive-apps-script', fileCount: files.length }
  };
}

function collectPdfFiles(folder, semesterId, semesterName, materialName, depth, semesterFiles, allFiles, sectionFolder) {
  if (depth > MAX_DEPTH) return;
  if (allFiles.length >= MAX_FILES) throw new Error('تجاوز عدد الملفات الحد الآمن: ' + MAX_FILES);

  var fileIterator = folder.getFilesByType(MimeType.PDF);
  while (fileIterator.hasNext()) {
    if (allFiles.length >= MAX_FILES) throw new Error('تجاوز عدد الملفات الحد الآمن: ' + MAX_FILES);
    var file = fileIterator.next();
    var currentMaterialName = materialName || null;
    semesterFiles.push(file.getId());
    var item = {
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
    };
    allFiles.push(item);
  }

  var childIterator = folder.getFolders();
  while (childIterator.hasNext()) {
    var child = childIterator.next();
    var childMaterialName = materialName;
    if (folder.getId() === semesterId) childMaterialName = child.getName();
    collectPdfFiles(child, semesterId, semesterName, childMaterialName, depth + 1, semesterFiles, allFiles, sectionFolder);
  }
}

function safeFileSize(file) {
  try { return Number(file.getSize() || 0); } catch (e) { return 0; }
}

function isPinnedDescription(description) {
  var desc = String(description || '').toLowerCase();
  return ['pinned', 'مثبت', 'مثبّت'].some(function(k) { return desc.indexOf(k.toLowerCase()) !== -1; });
}

function naturalNameCompare(a, b) {
  var na = extractNumber(a), nb = extractNumber(b);
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
      if (data[i][0] === fileId) { rowIndex = i; break; }
    }
    var now = new Date();
    if (rowIndex === -1) sheet.appendRow([fileId, fileName || '', 1, now]);
    else {
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
  Logger.log(JSON.stringify({ success: true, root: root.getName(), rootId: root.getId() }));
}
