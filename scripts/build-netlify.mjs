import { copyFile, cp, mkdir, readFile, rm, stat } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const webRoot = resolve(root, 'website');
const isWindows = process.platform === 'win32';
const flutter = isWindows ? 'flutter.bat' : 'flutter';
function run(command, args, options = {}) {
  const childOptions = { cwd: root, stdio: 'inherit', ...options };
  if (isWindows && command.toLowerCase().endsWith('.bat')) {
    execFileSync(process.env.ComSpec || 'cmd.exe', ['/d', '/s', '/c', [command, ...args].join(' ')], childOptions);
    return;
  }
  execFileSync(command, args, childOptions);
}

const config = await readFile(resolve(root, 'lib/core/config/supabase_config.dart'), 'utf8');
const extract = (name) => config.match(new RegExp(`${name}\\s*=\\s*String\\.fromEnvironment\\(\\s*'[^']+'\\s*,\\s*defaultValue:\\s*'([^']+)'`, 's'))?.[1] || '';
const environment = {
  ...process.env,
  PUBLIC_SUPABASE_URL: process.env.PUBLIC_SUPABASE_URL || extract('url'),
  PUBLIC_SUPABASE_ANON_KEY: process.env.PUBLIC_SUPABASE_ANON_KEY || extract('anonKey'),
};
for (const key of ['PUBLIC_SUPABASE_URL', 'PUBLIC_SUPABASE_ANON_KEY']) {
  if (!/^[A-Za-z0-9._:/=-]+$/.test(environment[key])) {
    throw new Error(`${key} contains characters unsupported by the Windows Flutter build command.`);
  }
}

run(process.execPath, [resolve(webRoot, 'scripts/copy-brand.mjs')], { cwd: webRoot, env: environment });
run(process.execPath, [resolve(webRoot, 'node_modules/astro/bin/astro.mjs'), 'build'], { cwd: webRoot, env: environment });
run(flutter, ['pub', 'get']);
run(flutter, ['build', 'web', '--release', '--no-wasm-dry-run', '--base-href=/app/', `--dart-define=SUPABASE_URL=${environment.PUBLIC_SUPABASE_URL}`, `--dart-define=SUPABASE_ANON_KEY=${environment.PUBLIC_SUPABASE_ANON_KEY}`]);

const appOutput = resolve(root, 'build/web');
const appDestination = resolve(webRoot, 'dist/app');
await rm(appDestination, { recursive: true, force: true });
await mkdir(appDestination, { recursive: true });
for (const name of ['index.html', 'flutter.js', 'flutter_bootstrap.js', 'main.dart.js', 'version.json', 'manifest.json', 'favicon.png', 'icons', 'assets', 'canvaskit', 'flutter_service_worker.js']) {
  const source = resolve(appOutput, name);
  const destination = resolve(appDestination, name);
  try {
    const info = await stat(source);
    if (info.isDirectory()) await cp(source, destination, { recursive: true });
    else await copyFile(source, destination);
  } catch (error) { if (error.code !== 'ENOENT') throw error; }
}

console.log(`Netlify site is ready at ${resolve(webRoot, 'dist')}`);
