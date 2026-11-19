import { execFileSync } from 'node:child_process';
import { cpSync, mkdirSync, readdirSync, readFileSync, renameSync, unlinkSync } from 'node:fs';
import path from 'node:path';
execFileSync(process.execPath, ['node_modules/typescript/bin/tsc', '--noEmit'], { stdio: 'inherit' });
execFileSync(process.execPath, ['node_modules/vite/bin/vite.js', 'build', '--config', 'vite.android.config.ts'], { stdio: 'inherit' });
mkdirSync('dist-android/icons', { recursive: true });
cpSync('public/icons', 'dist-android/icons', { recursive: true });
cpSync('public/licenses', 'dist-android/licenses', { recursive: true });
renameSync('dist-android/android.html', 'dist-android/index.html');
const target = 'A:/Dev/Studio/Projects/Ailiaili/development/PiliPlus/assets/canvas';
mkdirSync(target, { recursive: true });
cpSync('dist-android', target, { recursive: true });
const index = readFileSync(path.join(target, 'index.html'), 'utf8');
for (const file of readdirSync(path.join(target, 'assets'))) {
  if (!index.includes(file) && /\.(js|css)$/.test(file)) unlinkSync(path.join(target, 'assets', file));
}
console.log('Bundled production canvas copied to the Android project.');
