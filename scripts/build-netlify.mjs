import { execFileSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const webRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..', 'website');
const env = process.env;

execFileSync(process.execPath, [resolve(webRoot, 'scripts/copy-brand.mjs')], {
  cwd: webRoot,
  stdio: 'inherit',
  env,
});
execFileSync(process.execPath, [resolve(webRoot, 'node_modules/astro/bin/astro.mjs'), 'build'], {
  cwd: webRoot,
  stdio: 'inherit',
  env,
});

console.log(`Netlify website is ready at ${resolve(webRoot, 'dist')}`);
