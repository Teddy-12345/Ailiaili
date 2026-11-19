import { defineConfig } from 'vite';
export default defineConfig({
  base: './',
  build: { outDir: 'dist-android', copyPublicDir: false, rollupOptions: { input: 'android.html' } },
});
