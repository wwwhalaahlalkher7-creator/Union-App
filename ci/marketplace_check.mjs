import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
const root = process.cwd();
const read = p => readFileSync(join(root, p), 'utf8');
const migration = read('services/api/migrations/0031_marketplace_items.sql');
const admin = read('services/api/src/admin.js');
const pub = read('services/api/src/public.js');
const router = read('services/api/src/index.js');
const app = read('apps/student/lib/features/market/market_screen.dart');
const dashboard = read('web/portal/admin/market.html');
const layout = read('web/portal/admin/js/layout.js');
const checks = [
  ['D1 catalog table and public index', /CREATE TABLE IF NOT EXISTS market_items/.test(migration) && /idx_market_items_public_order/.test(migration)],
  ['admin CRUD allowlist', /market_items: \['title_ar','title_en','description_ar','description_en','category','price_label','image_url','contact_url','department_id','status','active','sort_order'\]/.test(admin) && /'market-items':'market_items'/.test(admin)],
  ['published-only public filter', /m\.active=1/.test(pub) && /m\.status='published'/.test(pub)],
  ['public route wired', /path === '\/market\/items'.*publicMarketItems/.test(router)],
  ['Flutter fetches live catalog', /getJson\('\/api\/v1\/market\/items'/.test(app) && !/Coming Soon/.test(app)],
  ['dashboard has create/update/delete', /method:id\?'PATCH':'POST'/.test(dashboard) && /method:'DELETE'/.test(dashboard)],
  ['dashboard navigation and content-manager access', /href: "market\.html"/.test(layout) && /"content_manager": \["dashboard", "news", "market"\]/.test(layout)],
  ['dashboard page exists', existsSync(join(root, 'web/portal/admin/market.html'))],
];
for (const [name, pass] of checks) { console.log(`${pass ? 'PASS' : 'FAIL'} ${name}`); if (!pass) process.exitCode = 1; }
if (!process.exitCode) console.log('MARKETPLACE CHECK PASSED');
