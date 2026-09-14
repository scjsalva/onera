import { createApp } from 'vue';
import http from '@/lib/http';
import { startRevealObserver } from '@/lib/reveal';
import { applyTheme, watchSystemTheme } from '@/lib/theme';
import { formatMoney, formatMinor } from '@/lib/money';

// Mirrors the Rails-monolith pattern: one Vue app mounted over the server
// rendered layout, with components dropped into HAML as custom elements.
// Vue enhances islands of interactivity; it never owns routing or data.
const app = createApp({
  name: 'OneraRoot',
  data() {
    return { userMenuOpen: false, mobileNavOpen: false };
  },
  methods: {
    closeMenus() {
      this.userMenuOpen = false;
      this.mobileNavOpen = false;
    },
  },
});

const modules = import.meta.glob('@/components/**/*.vue', { eager: true });
for (const [path, module] of Object.entries(modules)) {
  const name = path.split('/').pop().replace(/\.vue$/, '');
  app.component(name, module.default);
}

app.config.globalProperties.$http = http;
app.config.globalProperties.$formatMoney = formatMoney;
app.config.globalProperties.$formatMinor = formatMinor;

applyTheme();
watchSystemTheme();

document.addEventListener('DOMContentLoaded', () => {
  const root = document.querySelector('#vue');
  if (root) app.mount(root);
  startRevealObserver();
});

window.Onera = { app, http };
