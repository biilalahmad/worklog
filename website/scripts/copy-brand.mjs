import { copyFile, mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const websiteRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const repoRoot = resolve(websiteRoot, '..');
const brandRoot = resolve(websiteRoot, 'public', 'brand');

await mkdir(brandRoot, { recursive: true });
await copyFile(
  resolve(repoRoot, 'assets', 'images', 'worklog_icon.png'),
  resolve(brandRoot, 'worklog-icon.png'),
);
await copyFile(
  resolve(repoRoot, 'web', 'favicon.png'),
  resolve(websiteRoot, 'public', 'favicon.png'),
);
const publicOrigin = process.env.PUBLIC_SITE_URL || 'https://worklog.netlify.app';
await writeFile(
  resolve(websiteRoot, 'public', 'robots.txt'),
  `User-agent: *\nDisallow: /app/\nDisallow: /invoice/\nSitemap: ${publicOrigin.replace(/\/$/, '')}/sitemap-index.xml\n`,
);
