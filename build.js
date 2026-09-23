import fs from 'fs';
import path from 'path';

const rootDir = process.cwd();
const websiteDir = path.join(rootDir, 'website');
const adminDir = path.join(websiteDir, 'admin');
const distDir = path.join(rootDir, 'dist');
const distAdminDir = path.join(distDir, 'admin');

console.log('[BUILD] Starting packaging for TRINEX portal & admin...');

function copyDirRecursive(src, dest, excludeFilter = () => false) {
  if (!fs.existsSync(dest)) {
    fs.mkdirSync(dest, { recursive: true });
  }

  const entries = fs.readdirSync(src, { withFileTypes: true });

  for (const entry of entries) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);

    if (excludeFilter(entry.name, srcPath)) {
      continue;
    }

    if (entry.isDirectory()) {
      copyDirRecursive(srcPath, destPath, excludeFilter);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

// Clean dist directory
if (fs.existsSync(distDir)) {
  fs.rmSync(distDir, { recursive: true, force: true });
}
fs.mkdirSync(distDir, { recursive: true });

// Copy public website assets to dist
copyDirRecursive(websiteDir, distDir, (name, fullPath) => {
  if (name === 'admin' || name === 'worker' || name === 'wrangler.toml' || name === 'node_modules' || name.endsWith('.zip')) {
    return true;
  }
  if (name.startsWith('README') && name.endsWith('.md')) {
    return true;
  }
  return false;
});

// Copy the canonical admin UI to dist/admin only.
// Do not publish a second /dashboard tree: /admin is the single public admin URL.
copyDirRecursive(adminDir, distAdminDir, (name) => {
  if (name === 'worker' || name === 'wrangler.toml' || name === 'node_modules') {
    return true;
  }
  if (name.startsWith('README') && name.endsWith('.md')) {
    return true;
  }
});

// Verify required outputs exist
const requiredFiles = [
  path.join(distDir, 'index.html'),
  path.join(distDir, 'courses.html'),
  path.join(distDir, 'news.html'),
  path.join(distAdminDir, 'index.html'),
  path.join(distAdminDir, 'login.html'),
  path.join(distAdminDir, 'config.js'),
];

for (const file of requiredFiles) {
  if (!fs.existsSync(file)) {
    console.error(`[BUILD ERROR] Missing expected file: ${file}`);
    process.exit(1);
  }
}

console.log('[BUILD] Validation passed: All public pages and admin UI packaged successfully.');
console.log(`[BUILD] Dist ready at ${distDir}`);
