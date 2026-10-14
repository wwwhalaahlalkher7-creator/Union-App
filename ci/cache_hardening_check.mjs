import fs from 'node:fs';
const read = (p) => fs.readFileSync(new URL(`../${p}`, import.meta.url), 'utf8');
const api = read('flutter/lib/core/network/api_client.dart');
const offline = read('flutter/lib/core/network/offline_cache.dart');
const media = read('flutter/lib/features/news/media_screen.dart');
const contentRepo = read('flutter/lib/data/repositories/content_repository.dart');
const publicApi = read('backend/src/public.js');
const eino = read('backend/src/eino.js');
const core = read('backend/src/core.js');
const wrangler = read('backend/wrangler.toml');
const news = read('website/news.html');
const activities = read('website/activities.html');
const achievements = read('website/Injazat.html');
const courses = read('website/courses.html');
const checks = [
  ['student data stored through secure storage adapter', offline.includes('FlutterSecureStorage') && offline.includes('_secureStorageKey')],
  ['logout/account-scope cleanup', api.includes('clearCurrentStudentCache') && offline.includes('removePrefix')],
  ['personal chat/learning cache is account scoped', api.includes("p.startsWith('/api/v1/eino/chats')") && api.includes("p.startsWith('/api/v1/progress')") && api.includes("persistentCacheKey.startsWith('student:')")],
  ['Flutter public content pages capped at 50', contentRepo.includes("'${limit.clamp(1, 50)}'") && media.includes('static const int _pageSize = 50')],
  ['public content endpoint supports offset', publicApi.includes('LIMIT ? OFFSET ?') && publicApi.includes('hasMore: data.length === limit')],
  ['public materials endpoint supports offset', publicApi.includes('hasMore: rows.length === limit')],
  ['Eino Drive cache uses file ID + modification version', eino.includes('/__internal-cache/eino-material/') && eino.includes('row.drive_modified_at || row.updated_at || row.created_at')],
  ['Eino Drive cache TTL is six hours', eino.includes("'cache-control': 'public, max-age=21600'")],
  ['Eino global daily quota is 2000', core.includes('EINO_GLOBAL_DAILY_LIMIT_DEFAULT = 2000') && /EINO_GLOBAL_DAILY_LIMIT\s*=\s*"2000"/.test(wrangler)],
  ['news list pagination', news.includes('PUBLIC_PAGE_SIZE = 50') && news.includes('loadMoreNews')],
  ['activities list pagination', activities.includes('ACTIVITIES_PAGE_SIZE = 50') && activities.includes('activitiesLoadMore')],
  ['achievements list pagination', achievements.includes('ACHIEVEMENTS_PAGE_SIZE = 50') && achievements.includes('loadMoreAchievements')],
  ['materials catalogue pagination', courses.includes('MATERIALS_PAGE_SIZE = 50') && courses.includes('loadMoreMaterials')],
  ['website stale cache refreshes in background', news.includes('refreshInBackground().catch(() => {})') && courses.includes('background: true')],
];
let failed = false;
for (const [name, ok] of checks) { console.log(`${ok ? 'PASS' : 'FAIL'} ${name}`); if (!ok) failed = true; }
if (failed) process.exit(1);
console.log('CACHE HARDENING CHECK PASSED');
