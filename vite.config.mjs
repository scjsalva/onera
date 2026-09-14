import { defineConfig } from 'vite';
import RubyPlugin from 'vite-plugin-ruby';
import vue from '@vitejs/plugin-vue';
import { fileURLToPath, URL } from 'node:url';

export default defineConfig({
  plugins: [RubyPlugin(), vue()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./app/javascript/src', import.meta.url)),
      // The app mounts over server-rendered HAML, so Vue has to compile
      // in-DOM templates at runtime. The default import is runtime-only and
      // would silently render nothing.
      vue: 'vue/dist/vue.esm-bundler.js',
    },
  },
  define: {
    __VUE_OPTIONS_API__: 'true',
    __VUE_PROD_DEVTOOLS__: 'false',
    __VUE_PROD_HYDRATION_MISMATCH_DETAILS__: 'false',
  },
});
