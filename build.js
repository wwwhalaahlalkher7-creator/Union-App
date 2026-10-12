import fs from 'fs';
import path from 'path';

const rootDir = process.cwd();
const websiteDir = path.join(rootDir, 'website');
const distDir = path.join(rootDir, 'dist');

console.log('[BUILD] Packaging TRINEX public website; administration is native Flutter only.');

function copyDirRecursive(src, dest, excludeFilter = () => false) {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (excludeFilter(entry.name, srcPath)) continue;
    if (entry.isDirectory()) copyDirRecursive(srcPath, destPath, excludeFilter);
    else fs.copyFileSync(srcPath, destPath);
  }
}
if (fs.existsSync(distDir)) fs.rmSync(distDir, { recursive: true, force: true });
fs.mkdirSync(distDir, { recursive: true });
copyDirRecursive(websiteDir, distDir, (name) =>
  name === 'admin' || name === 'worker' || name === 'wrangler.toml' ||
  name === 'node_modules' || name.endsWith('.zip') ||
  (name.startsWith('README') && name.endsWith('.md'))
);
for (const file of ['index.html', 'courses.html', 'news.html', 'download.html']) {
  if (!fs.existsSync(path.join(distDir, file))) {
    console.error(`[BUILD ERROR] Missing expected public file: ${file}`);
    process.exit(1);
  }
}
if (fs.existsSync(path.join(distDir, 'admin'))) {
  console.error('[BUILD ERROR] Admin web files must not be published.');
  process.exit(1);
}
console.log('[BUILD] Validation passed: public website packaged; no web admin included.');
console.log(`[BUILD] Dist ready at ${distDir}`);
