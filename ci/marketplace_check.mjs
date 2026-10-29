import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();
const read = path => readFileSync(join(root, path), 'utf8');
const migration = read('services/api/migrations/0031_marketplace_items.sql');
const admin = read('services/api/src/admin.js');
const pub = read('services/api/src/public.js');
const router = read('services/api/src/index.js');
const app = read('apps/student/lib/features/market/market_screen.dart');
const nativeAdmin = read('apps/admin/lib/src/features/marketplace/marketplace_exams_page.dart');
const nativeNav = read('apps/admin/lib/src/admin_permissions.dart');
const checks = [
  ['D1 catalog table and public index', /CREATE TABLE IF NOT EXISTS market_items/.test(migration) && /idx_market_items_public_order/.test(migration)],
  ['admin CRUD allowlist', /market_items: \['title_ar','title_en','description_ar','description_en','category','price_label','image_url','contact_url','department_id','status','active','sort_order'\]/.test(admin) && /'market-items':'market_items'/.test(admin)],
  ['published-only public filter', /m\.active=1/.test(pub) && /m\.status='published'/.test(pub)],
  ['public route wired', /path === '\/market\/items'.*publicMarketItems/.test(router)],
  ['Flutter student app fetches live catalog', /getJson\('\/api\/v1\/market\/items'/.test(app) && !/Coming Soon/.test(app)],
  ['native admin supports marketplace create/update/delete', nativeAdmin.includes("'/admin/market-items") && /widget\.api\.post\('\/admin\/market-items'/.test(nativeAdmin) && /widget\.api\.patch\('\/admin\/market-items\/\$id'/.test(nativeAdmin) && /widget\.api\.delete\('\/admin\/market-items\/\$id'/.test(nativeAdmin)],
  ['content manager can access standalone marketplace section', /AdminSection\.market/.test(nativeNav) && /contentManager/.test(nativeNav)],
  ['legacy website-admin dashboard is intentionally absent', !existsSync(join(root, 'web/portal/admin/market.html'))],
];
for (const [name, pass] of checks) {
  console.log(`${pass ? 'PASS' : 'FAIL'} ${name}`);
  if (!pass) process.exitCode = 1;
}
if (!process.exitCode) console.log('MARKETPLACE CHECK PASSED');
