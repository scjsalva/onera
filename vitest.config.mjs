import { defineConfig } from 'vitest/config';
import vue from '@vitejs/plugin-vue';
import { fileURLToPath, URL } from 'node:url';

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: { '@': fileURLToPath(new URL('./app/javascript/src', import.meta.url)) },
  },
  test: {
    environment: 'jsdom',
    include: ['test/javascript/**/*.test.mjs'],
    globals: true,
  },
});
